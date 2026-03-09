# frozen_string_literal: true

require "net/http"
require "json"
require "openssl"

# Calls Microsoft Graph API to list SharePoint sites and drive items.
# Credentials are stored in Setting table:
#   Setting.sharepoint_tenant_id
#   Setting.sharepoint_client_id
#   Setting.sharepoint_client_secret
#
# list_sites always returns ServiceResult with:
#   result: { sites: Array, next_cursor: String|nil }
#
# Pass cursor: (next_cursor from a previous call) to fetch the next page.

# ── Persistent stores ─────────────────────────────────────────────────────────
# Defined outside SharepointService with `unless defined?` so they are NOT
# wiped when Zeitwerk reloads the class file in development mode.
#
# SP_TOKEN_STORE  – caches OAuth2 access tokens (~1 h TTL from Azure)
# SP_RESULT_STORE – caches site-search results for 2 min (repeat searches instant)
# ---------------------------------------------------------------------------
# rubocop:disable Style/MutableConstant
unless defined?(SP_TOKEN_STORE)
  SP_TOKEN_STORE       = {}
  SP_TOKEN_STORE_MUTEX = Mutex.new
end

unless defined?(SP_RESULT_STORE)
  SP_RESULT_STORE       = {}
  SP_RESULT_STORE_MUTEX = Mutex.new
end
# rubocop:enable Style/MutableConstant

class SharepointService
  GRAPH_BASE       = "https://graph.microsoft.com/v1.0"
  RESULT_CACHE_TTL = 120 # seconds — search results are cached for 2 minutes

  # Resolved once at load time — avoids repeated File.exist? probes per request.
  CA_FILE = [
    ENV.fetch("SSL_CERT_FILE", nil),
    "/opt/homebrew/etc/ca-certificates/cert.pem",  # macOS Apple Silicon (Homebrew)
    "/usr/local/etc/ca-certificates/cert.pem",     # macOS Intel (Homebrew)
    "/usr/local/etc/openssl@3/cert.pem",            # macOS Homebrew OpenSSL 3
    "/usr/local/etc/openssl/cert.pem",              # macOS Homebrew OpenSSL
    "/etc/ssl/cert.pem",                            # Alpine Linux / macOS system
    "/etc/ssl/certs/ca-certificates.crt",           # Debian/Ubuntu
    "/etc/pki/tls/certs/ca-bundle.crt",             # RHEL/CentOS
    OpenSSL::X509::DEFAULT_CERT_FILE.to_s
  ].compact.find { |p| p.present? && File.exist?(p) }

  def initialize(config: {})
    @tenant = config["tenant_id"].presence || Setting.sharepoint_tenant_id.presence
    @client = config["client_id"].presence || Setting.sharepoint_client_id.presence
    @secret = config["client_secret"].presence || Setting.sharepoint_client_secret.presence
  end

  # Returns { sites: Array, next_cursor: String|nil }.
  # Pass cursor: to fetch the next page of a previous keyword search.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
  def list_sites(query: nil, cursor: nil)
    token_result = fetch_token
    return token_result unless token_result.success?

    token = token_result.result

    # Cursor-based continuation — skip cache, validate URL is a Graph sites endpoint.
    if cursor.present?
      raise ArgumentError, "Invalid cursor" unless cursor.start_with?("#{GRAPH_BASE}/sites")

      raw, next_link = fetch_page(URI(cursor), token)
      return ServiceResult.success(result: { sites: map_sites(raw), next_cursor: next_link })
    end

    # Keyword search — serve from result cache when available (first page only).
    if query.present?
      cached = result_cache_read(query)
      return ServiceResult.success(result: cached) if cached
    end

    search = query.present? ? URI.encode_www_form_component(query) : "*"
    top    = query.present? ? 20 : 999
    uri    = URI("#{GRAPH_BASE}/sites?search=#{search}" \
                 "&$select=id,displayName,webUrl,description,createdDateTime,createdBy" \
                 "&$top=#{top}")

    if query.present?
      # Single-page fetch; next_cursor lets callers load more on demand.
      raw, next_link = fetch_page(uri, token)
      result = { sites: map_sites(raw), next_cursor: next_link }
      result_cache_write(query, result)
    else
      # Full pagination for admin "load all" (search=*); no cursor needed.
      raw    = fetch_all_pages(uri, token)
      result = { sites: map_sites(raw), next_cursor: nil }
    end

    ServiceResult.success(result: result)
  rescue StandardError => e
    ServiceResult.failure(errors: [e.message])
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize
  def list_drive_items(site_id:, folder_id: nil)
    token_result = fetch_token
    return token_result unless token_result.success?

    token = token_result.result
    path  = if folder_id
              "#{GRAPH_BASE}/sites/#{site_id}/drive/items/#{folder_id}/children"
            else
              "#{GRAPH_BASE}/sites/#{site_id}/drive/root/children"
            end
    uri   = URI("#{path}?$select=id,name,webUrl,file,folder,size," \
                "lastModifiedDateTime,lastModifiedBy&$top=999")
    raw   = fetch_all_pages(uri, token)
    items = raw.map do |item|
      {
        id: item["id"],
        name: item["name"],
        web_url: item["webUrl"],
        is_folder: item.key?("folder"),
        size: item["size"],
        modified_at: item["lastModifiedDateTime"],
        modified_by: item.dig("lastModifiedBy", "user", "displayName")
      }
    end
    ServiceResult.success(result: items)
  rescue StandardError => e
    ServiceResult.failure(errors: [e.message])
  end
  # rubocop:enable Metrics/AbcSize

  private

  def map_sites(raw)
    raw.map do |s|
      {
        id: s["id"],
        name: s["displayName"],
        web_url: s["webUrl"],
        description: s["description"],
        created_at: s["createdDateTime"],
        created_by: s.dig("createdBy", "user", "displayName")
      }
    end
  end

  # Fetches a single page and returns [items_array, next_link_or_nil].
  def fetch_page(uri, token)
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"]        = "application/json"

    resp = http(uri).request(req)
    data = JSON.parse(resp.body)

    raise data.dig("error", "message") || resp.message unless resp.is_a?(Net::HTTPSuccess)

    [data["value"] || [], data["@odata.nextLink"]]
  end

  # Fetches every page from the Graph API by following @odata.nextLink links.
  # rubocop:disable Metrics/AbcSize
  def fetch_all_pages(initial_uri, token)
    result = []
    uri    = initial_uri
    loop do
      items, next_link = fetch_page(uri, token)
      result.concat(items)
      break if next_link.blank?

      uri = URI(next_link)
    end
    result
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
  def fetch_token
    return ServiceResult.failure(errors: ["SharePoint credentials not configured"]) unless @tenant && @client && @secret

    cache_key = "#{@tenant}/#{@client}"

    SP_TOKEN_STORE_MUTEX.synchronize do
      entry = SP_TOKEN_STORE[cache_key]
      return ServiceResult.success(result: entry[:token]) if entry && entry[:expires_at] > Time.current
    end

    uri = URI("https://login.microsoftonline.com/#{@tenant}/oauth2/v2.0/token")
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(
      grant_type: "client_credentials",
      client_id: @client,
      client_secret: @secret,
      scope: "https://graph.microsoft.com/.default"
    )

    resp = http(uri).request(req)
    data = JSON.parse(resp.body)

    if resp.is_a?(Net::HTTPSuccess)
      token = data["access_token"]
      ttl   = [data["expires_in"].to_i - 60, 3000].min
      if ttl.positive?
        SP_TOKEN_STORE_MUTEX.synchronize do
          SP_TOKEN_STORE[cache_key] = { token: token, expires_at: Time.current + ttl }
        end
      end
      ServiceResult.success(result: token)
    else
      ServiceResult.failure(errors: [data["error_description"] || resp.message])
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

  def result_cache_read(query)
    SP_RESULT_STORE_MUTEX.synchronize do
      entry = SP_RESULT_STORE[query.downcase]
      entry[:data] if entry && entry[:expires_at] > Time.current
    end
  end

  def result_cache_write(query, data)
    SP_RESULT_STORE_MUTEX.synchronize do
      SP_RESULT_STORE[query.downcase] = { data: data, expires_at: Time.current + RESULT_CACHE_TTL }
    end
  end

  def http(uri)
    h = Net::HTTP.new(uri.host, uri.port)
    h.use_ssl      = true
    h.verify_mode  = OpenSSL::SSL::VERIFY_PEER
    h.open_timeout = 5
    h.read_timeout = 15
    h.ca_file      = CA_FILE if CA_FILE
    h
  end
end
