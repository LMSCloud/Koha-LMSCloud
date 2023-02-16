[% MACRO jsextrainclude BLOCK %]
    <script type="text/javascript">
    //<![CDATA[

        var categories = {};
        var selcateg = '[% selcateg | html %]';
        [% FOREACH category IN additionalparameters.categories %]
            categories["[% category.categorycode | html %]"] = { name: "[% category.categoryname | html %]", libraries: [], sel: false};
        [% END %]
        if ( selcateg != '' ) {
            categories[selcateg]["sel"] = true;
        }
        
        var libraries = {};
        var libcodes = new Array();
        [% FOREACH branchloo IN additionalparameters.branchloop %]
            libraries["[% branchloo.value | html %]"] = { name: "[% branchloo.branchname | html %]", category: [] };
            libcodes.push("[% branchloo.value | html %]");
            [% FOREACH branchcategory IN branchloo.category.keys %]
                libraries["[% branchloo.value | html %]"]["category"].push("[% branchcategory | html %]");
                categories["[% branchcategory | html %]"]["libraries"].push("[% branchloo.value | html %]");
            [% END %]
        [% END %]
        
        function resetLibrarySelection() {
            var selgroup = $( "#groups" ).val();
            var libs = new Array();
            var libselect = $("#branches");
            
            if ( selgroup == '*' ) {
                libcodes.forEach(function(library) {
                    libs.push([library,libraries[library].name]);
                });
            }
            else {
                categories[selgroup]['libraries'].forEach(function(library) {
                    libs.push([library,libraries[library].name]);
                });
            }
            
            $('#branches option[value!="*"]').remove();
            
            $.each(libs, function(idx, value) {
                libselect.append($('<option></option>').val(value[0]).html(value[1]));
            });
        }
     
        $(document).ready(function() {
            var sel = $('#groups');
            
            var selectedgroup = "[% additionalparameters.selectedgroup %]";
            var selectedbranch = "[% additionalparameters.selectedbranch %]";
            
            $.each(categories, function(code, categ) {
                sel.append($('<option></option>').val(code).html(categ.name).attr('selected', categ.sel));
            });
            
            sel.val(selectedgroup).change();
            resetLibrarySelection();
            
            sel.on('change', function() {
                resetLibrarySelection();
            });
            $('#branches').val(selectedbranch).change();
        });
    //]]>
    </script>
[% END %]

        <fieldset class="rows">
            <legend>Additional parameters</legend>
            <ol>
                <li>
                    <label for="selectedgroup" >Select a group:</label>
                    <select name="selectedgroup" id="groups" required="required">
                    <option value="*">All library categories</option>
                    </select>
                    <span class="required">Required</span>
                </li>
                <li>
                    <label for="selectedbranch" >Select a library:</label>
                    <select name="selectedbranch" id="branches" required="required">
                    <option value="*">All libraries</option>
                    </select>
                    <span class="required">Required</span>
                </li>
            </ol>
        </fieldset>
        

        <fieldset class="rows">
            <legend>Item type settings</legend>
            <div style="margin: 0em 1em 1em">
                Koha media types need to be mapped to VG WORT media types. 
                Items of unmapped item types will be ignored with the VG Wort export.<br>
                Onleihe media types should be ignored.
            </div>
            <table>
                <thead>
                    <th>Koha media type</th>
                    <th>VG WORT media type</th>
                </thead>
                <tbody>
                    [% FOREACH itemtype IN additionalparameters.itemtypes %]
                    <tr>
                        <td>[% itemtype.description | html %] ([% itemtype.itemtype | html %])</td>
                        <td>
                            <select name="itype_[% itemtype.name | html %]">
                                <option value=""></option>
                                [% FOREACH vtype IN additionalparameters.vgworttypes %]
                                    [% IF vtype.value == itemtype.mapped %]
                                        <option value="[% vtype.value | html %]" selected>[% vtype.name | html %]</option>
                                    [% ELSE %]
                                        <option value="[% vtype.value | html %]">[% vtype.name | html %]</option>
                                    [% END %]
                                [% END %]
                            </select>
                        </td>
                    </tr>
                    [% END %]
                </tbody>
            </table>
		</fieldset>

