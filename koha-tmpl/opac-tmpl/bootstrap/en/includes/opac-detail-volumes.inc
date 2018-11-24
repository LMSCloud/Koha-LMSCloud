[% IF (VolumeData && VolumeData.size > 0 ) %]
    <div class="detail_volume_list">
        <div id="toolbar" class="toolbar clearfix">
            <div class="container-fluid">
                <div class="row">
                    <div class="span12">
                        <div class="detail_volume_header">Parts of the work ([% VolumeData.size %])</div>
                    </div>
                </div>
            </div>
        </div>
        <table class="table table-striped">
            <tbody>
            [% FOREACH Volume IN VolumeData %]
                <tr>
                    <td class="bibliocol" style="">
                        <div class="detail_volume_volname">
                            [% IF (Volume.sortvolume) %][% Volume.sortvolume %][% END %][% IF (Volume.sortpart) %][% IF (Volume.sortvolume) %], [% END %][% Volume.sortpart %][% END %]
                        </div>
                    
                    </td>
                    <td>
                        <div class="detail_volume_bibdata">
                            [% Volume.XSLTResultsRecord %]
                        </div>
                    </td>
                </tr>
            [% END %]
            <tbody>
        </table>
    </div>
[% END %]
[% IF (LinkedRecordData && LinkedRecordData.size > 0 ) %]
    <div class="detail_linked_record_list">
        <div id="toolbar" class="toolbar clearfix">
            <div class="container-fluid">
                <div class="row">
                    <div class="span12">
                        [% IF (LinkedRecordData.size == 1) %]
                            <div class="detail_linked_record_header">The title is part fo the following work</div>
                        [% ELSE %]
                            <div class="detail_linked_record_header">The title is part fo the following works</div>
                        [% END %]
                    </div>
                </div>
            </div>
        </div>
        <table class="table table-striped">
            <tbody>
            [% FOREACH Volume IN LinkedRecordData %]
                <tr>
                    <td>
                        <div class="detail_linked_record_bibdata">
                            [% Volume.XSLTResultsRecord %]
                        </div>
                    </td>
                </tr>
            [% END %]
            <tbody>
        </table>
    </div>
[% END %]