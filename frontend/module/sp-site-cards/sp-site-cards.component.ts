import {
  AfterViewInit,
  ChangeDetectorRef,
  Component,
  ElementRef,
  OnDestroy,
  ViewChild,
  ViewEncapsulation,
} from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CdkDragDrop, moveItemInArray } from '@angular/cdk/drag-drop';

export interface SpSite {
  id: string;
  name: string;
  web_url: string;
  description: string;
  created_at: string;
}

@Component({
  selector: 'sp-site-cards',
  templateUrl: './sp-site-cards.component.html',
  styleUrls: ['./sp-site-cards.component.sass'],
  standalone: false,
  encapsulation: ViewEncapsulation.None,
})
export class SpSiteCardsComponent implements AfterViewInit, OnDestroy {
  // ── Attribute inputs (passed via HTML attributes on the custom element) ──
  placeholder  = 'Search SharePoint sites...';
  btnLabel     = 'Search';
  hintDefault  = 'Enter at least 3 characters to search.';
  hintMinChars = 'Enter at least 3 characters to search.';
  loadingText      = 'Loading sites...';
  loadingMoreText  = 'Loading more...';
  noResultsText    = 'No sites found.';
  sitesUrl         = '';

  @ViewChild('scrollAnchor') scrollAnchor?: ElementRef<HTMLElement>;
  @ViewChild('resultsScroll') resultsScroll?: ElementRef<HTMLElement>;

  // ── State ────────────────────────────────────────────────────────────────
  query       = '';
  hint        = '';
  hintIsError = false;
  hasSearched = false;
  loading     = false;
  loadingMore = false;
  error       = '';
  sites: SpSite[]     = [];
  nextCursor: string | null = null;
  selectedSite: SpSite | null = null;

  private observer: IntersectionObserver | null = null;

  constructor(
    private http: HttpClient,
    private hostEl: ElementRef<HTMLElement>,
    private cdr: ChangeDetectorRef,
  ) {}

  // ── Lifecycle ────────────────────────────────────────────────────────────

  ngAfterViewInit(): void {
    // Read attributes set by the ERB (custom-element attribute → property)
    const el = this.hostEl.nativeElement;
    this.sitesUrl        = el.getAttribute('sites-url')        || this.sitesUrl;
    this.placeholder     = el.getAttribute('placeholder')      || this.placeholder;
    this.btnLabel        = el.getAttribute('btn-label')        || this.btnLabel;
    this.hintDefault     = el.getAttribute('hint-default')     || this.hintDefault;
    this.hintMinChars    = el.getAttribute('hint-min-chars')   || this.hintMinChars;
    this.loadingText     = el.getAttribute('loading-text')     || this.loadingText;
    this.loadingMoreText = el.getAttribute('loading-more-text')|| this.loadingMoreText;
    this.noResultsText   = el.getAttribute('no-results-text')  || this.noResultsText;
    this.hint = this.hintDefault;
    this.cdr.detectChanges();
  }

  ngOnDestroy(): void {
    this.observer?.disconnect();
  }

  // ── Search ───────────────────────────────────────────────────────────────

  onSearch(): void {
    const q = this.query.trim();
    if (q.length < 3) {
      this.hint       = this.hintMinChars;
      this.hintIsError = true;
      return;
    }
    this.hint       = this.hintDefault;
    this.hintIsError = false;
    this.fetchSites(q, null);
  }

  onKeydown(event: KeyboardEvent): void {
    if (event.key === 'Enter') {
      event.preventDefault();
      this.onSearch();
    }
  }

  private fetchSites(q: string, cursor: string | null): void {
    if (cursor) {
      this.loadingMore = true;
    } else {
      this.loading     = true;
      this.sites       = [];
      this.nextCursor  = null;
      this.error       = '';
      this.selectedSite = null;
      this.hasSearched  = true;
    }

    let url = `${this.sitesUrl}?q=${encodeURIComponent(q)}`;
    if (cursor) url += `&cursor=${encodeURIComponent(cursor)}`;

    this.http.get<{ sites: SpSite[]; next_cursor: string | null }>(url).subscribe({
      next: (data) => {
        const incoming = data.sites || [];
        if (cursor) {
          this.sites      = [...this.sites, ...incoming];
          this.loadingMore = false;
        } else {
          this.sites   = incoming;
          this.loading = false;
          // Re-attach sentinel after first load
          setTimeout(() => this.setupScrollObserver(), 0);
        }
        this.nextCursor = data.next_cursor || null;
        this.cdr.detectChanges();
      },
      error: (err: { message?: string }) => {
        this.loading     = false;
        this.loadingMore = false;
        if (!cursor) this.error = err.message || 'Error loading sites';
        this.cdr.detectChanges();
      },
    });
  }

  // ── Infinite scroll ──────────────────────────────────────────────────────

  private setupScrollObserver(): void {
    this.observer?.disconnect();
    if (!this.scrollAnchor?.nativeElement) return;
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && this.nextCursor && !this.loadingMore) {
          this.fetchSites(this.query.trim(), this.nextCursor);
        }
      },
      { root: this.resultsScroll?.nativeElement, threshold: 0.1 },
    );
    this.observer.observe(this.scrollAnchor.nativeElement);
  }

  // ── CDK Drag & Drop ──────────────────────────────────────────────────────

  onDrop(event: CdkDragDrop<SpSite[]>): void {
    moveItemInArray(this.sites, event.previousIndex, event.currentIndex);
  }

  // ── Site selection ───────────────────────────────────────────────────────

  selectSite(site: SpSite): void {
    this.selectedSite = site;
    // Dispatch DOM event so the surrounding ERB page JS can react
    this.hostEl.nativeElement.dispatchEvent(
      new CustomEvent('siteSelected', { detail: site, bubbles: true }),
    );
    this.cdr.detectChanges();
  }

  trackBySiteId(_index: number, site: SpSite): string {
    return site.id;
  }
}
