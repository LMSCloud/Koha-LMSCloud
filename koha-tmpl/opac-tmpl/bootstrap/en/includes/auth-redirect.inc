[% USE UUID %]
[% SET auth_uuid = UUID.generate('auth') %]
[% IF loggedinusername %]
    [% content %]
[% ELSE %]
    <a class="btn btn-link btn-lg" data-auth-uuid="[% auth_uuid %]" href="/cgi-bin/koha/opac-user.pl"><i class="[% icon | html %]" aria-hidden="true"></i> [% label | html %]</a>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const link = document.querySelector('[data-auth-uuid="[% auth_uuid %]"]');
            if (link) {
                const baseUrl = '[% Koha.Preference("OPACBaseURL") | html %]';
                const currentPath = window.location.pathname + window.location.search;
                const fullUrl = baseUrl ? baseUrl + currentPath : window.location.origin + currentPath;
                const currentUrl = encodeURIComponent(fullUrl);
                const separator = link.href.includes('?') ? '&' : '?';
                link.href = link.href + separator + 'return=' + currentUrl;
            }
        });
    </script>
[% END %]