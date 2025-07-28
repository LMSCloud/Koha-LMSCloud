[%# Bookings timeline include for intranet templates %]

[%# Parameters:
    - timeline_id: ID for the timeline container (default: bookings-timeline)
    - loading_id: ID for the loading indicator (default: bookings-timeline-loading)
    - show_filters: Whether to show filter controls (default: 1)
    - show_expired_filter: Whether to show expired filter (default: 1)
    - show_cancelled_filter: Whether to show cancelled filter (default: 1)
%]

<div id="[% timeline_id || 'bookings-timeline' %]" class="position-relative bookings-timeline-container">
    [% IF show_filters %]
        <div class="page-section">
            <fieldset class="action filters d-flex gap-2" style="cursor: pointer;">
                [% IF show_expired_filter %]
                    <a id="expired_filter" data-filter="expired"><i class="fa fa-bars"></i> Show expired</a>
                [% END %]
                [% IF show_cancelled_filter %]
                    <a id="cancelled_filter" data-filter="cancelled"><i class="fa fa-bars"></i> Show cancelled</a>
                [% END %]
            </fieldset>
        </div>
    [% END %]
    
    <div class="position-absolute w-100 h-100 d-flex justify-content-center align-items-center bookings-timeline-loading-overlay"
         id="[% loading_id || 'bookings-timeline-loading' %]">
        <div class="bookings-timeline-loading">
            <i class="fa fa-spinner fa-spin"></i> Processing...
        </div>
    </div>
</div> 