[% IF (link) %]
<a class="btn btn-link btn-lg" data-booking-modal role="button"><i class="fa fa-fw fa-calendar"></i> Place Booking </a>
[% ELSE %]
<div class="btn-group">
    <button class="btn btn-default" data-booking-modal type="button"><i class="fa fa-calendar"></i> Place Booking </button>
</div>
[% END %]