<?xml version="1.0" encoding="UTF-8"?>
<!-- Created by LMSCloud GmbH 2018 -->
<!DOCTYPE stylesheet [<!ENTITY nbsp "&#160;" >]>
<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:items="http://www.koha-community.org/items"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:str="http://exslt.org/strings"
  exclude-result-prefixes="marc items">
    <xsl:import href="MARC21slimUtils.xsl"/>
    <xsl:output method = "html" indent="yes" omit-xml-declaration = "yes" encoding="UTF-8"/>
    <xsl:key name="item-by-status" match="items:item" use="items:status"/>
    <xsl:key name="item-by-status-and-branch-home" match="items:item" use="concat(items:status, ' ', items:homebranch)"/>
    <xsl:key name="item-by-status-and-branch-holding" match="items:item" use="concat(items:status, ' ', items:holdingbranch)"/>
    <xsl:key name="item-by-substatus-and-branch" match="items:item" use="concat(items:substatus, ' ', items:homebranch)"/>

    <xsl:template match="/">
            <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="marc:record">

    <xsl:variable name="itemcount" select="count(items:items/items:item)"/>
    
    <!-- Option: Display Alternate Graphic Representation (MARC 880)  -->
    <xsl:variable name="display880" select="boolean(marc:datafield[@tag=880])"/>

    <xsl:variable name="UseControlNumber" select="marc:sysprefs/marc:syspref[@name='UseControlNumber']"/>
    <xsl:variable name="UseAuthoritiesForTracings" select="marc:sysprefs/marc:syspref[@name='UseAuthoritiesForTracings']"/>
    <xsl:variable name="OPACResultsLibrary" select="marc:sysprefs/marc:syspref[@name='OPACResultsLibrary']"/>
    <xsl:variable name="hidelostitems" select="marc:sysprefs/marc:syspref[@name='hidelostitems']"/>
    <xsl:variable name="DisplayOPACiconsXSLT" select="marc:sysprefs/marc:syspref[@name='DisplayOPACiconsXSLT']"/>
    <xsl:variable name="OPACURLOpenInNewWindow" select="marc:sysprefs/marc:syspref[@name='OPACURLOpenInNewWindow']"/>
    <xsl:variable name="URLLinkText" select="marc:sysprefs/marc:syspref[@name='URLLinkText']"/>
    <xsl:variable name="Show856uAsImage" select="marc:sysprefs/marc:syspref[@name='OPACDisplay856uAsImage']"/>
    <xsl:variable name="AlternateHoldingsField" select="substring(marc:sysprefs/marc:syspref[@name='AlternateHoldingsField'], 1, 3)"/>
    <xsl:variable name="AlternateHoldingsSubfields" select="substring(marc:sysprefs/marc:syspref[@name='AlternateHoldingsField'], 4)"/>
    <xsl:variable name="AlternateHoldingsSeparator" select="marc:sysprefs/marc:syspref[@name='AlternateHoldingsSeparator']"/>
    <xsl:variable name="OPACItemLocation" select="marc:sysprefs/marc:syspref[@name='OPACItemLocation']"/>
    <xsl:variable name="singleBranchMode" select="marc:sysprefs/marc:syspref[@name='singleBranchMode']"/>
    <xsl:variable name="OPACTrackClicks" select="marc:sysprefs/marc:syspref[@name='TrackClicks']"/>
    <xsl:variable name="BiblioDefaultView" select="marc:sysprefs/marc:syspref[@name='BiblioDefaultView']"/>
    <xsl:variable name="IncludeAdditionalMARCFields" select="marc:sysprefs/marc:syspref[@name='IncludeAdditionalMARCFieldsInOPACVolumeView']"/>
    <xsl:variable name="SubjectModifier"><xsl:if test="marc:sysprefs/marc:syspref[@name='TraceCompleteSubfields']='1'">,complete-subfield</xsl:if></xsl:variable>
    <xsl:variable name="TraceSubjectSubdivisions" select="marc:sysprefs/marc:syspref[@name='TraceSubjectSubdivisions']"/>
    <xsl:variable name="ExcludeReviewsWithMARC520Indicator1Value" select="concat('|',translate(marc:sysprefs/marc:syspref[@name='ExcludeReviewsWithMARC520Indicator1Value'],'#',' '),'|')"/>
    <xsl:variable name="DivibibEnabled" select="marc:sysprefs/marc:syspref[@name='DivibibEnabled']"/>
    <xsl:variable name="TracingQuotesLeft">
      <xsl:choose>
        <xsl:when test="marc:sysprefs/marc:syspref[@name='UseICUStyleQuotes']='1'">{</xsl:when>
        <xsl:otherwise>"</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="TracingQuotesRight">
      <xsl:choose>
        <xsl:when test="marc:sysprefs/marc:syspref[@name='UseICUStyleQuotes']='1'">}</xsl:when>
        <xsl:otherwise>"</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="AntolinAdd">
        <xsl:if test="marc:datafield[@tag='856' and @ind1='4' and @ind2='2']/marc:subfield[@code='n' and text()='Antolin']">
            <img src="/webcustom/images/Antolin16.png" alt="Antolin book" title="Antolin book" class="materialtype mt_icon_antolin" /><xsl:text> </xsl:text>
        </xsl:if>
    </xsl:variable>
    <xsl:variable name="biblionumber" select="marc:datafield[@tag=999]/marc:subfield[@code='c']"/>

    <!-- Title Statement: Alternate Graphic Representation (MARC 880) -->
    <xsl:if test="$display880">
       <xsl:call-template name="m880Select">
          <xsl:with-param name="basetags">245</xsl:with-param>
          <xsl:with-param name="codes">abhfgknps</xsl:with-param>
          <xsl:with-param name="bibno"><xsl:value-of  select="$biblionumber"/></xsl:with-param>
       </xsl:call-template>
    </xsl:if>

    <a>
        <xsl:attribute name="href">
            <xsl:call-template name="buildBiblioDefaultViewURL">
                <xsl:with-param name="BiblioDefaultView">
                    <xsl:value-of select="$BiblioDefaultView"/>
                </xsl:with-param>
            </xsl:call-template>
            <xsl:value-of select="str:encode-uri($biblionumber, true())"/>
        </xsl:attribute>
        <xsl:attribute name="class">title</xsl:attribute>

        <!--Bug 13381 -->
        <xsl:choose>
            <xsl:when test="marc:datafield[@tag=245]">
                <h1 class="title" property="name">
                    <xsl:if test="marc:datafield[@tag=246 and @ind1='1' and @ind2 = '9']/marc:subfield[@code='a']">
                        <xsl:text>[</xsl:text><xsl:value-of select="marc:datafield[@tag=246 and @ind1='1' and @ind2 = '9']/marc:subfield[@code='a']" /><xsl:text>]: </xsl:text>
                    </xsl:if>
                    <xsl:for-each select="marc:datafield[@tag=245]">
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">a</xsl:with-param>
                        </xsl:call-template>
                        <xsl:text> </xsl:text>
                        <!-- 13381 add additional subfields-->
                        <xsl:for-each select="marc:subfield[contains('bchknps', @code)]">
                            <xsl:choose>
                                <xsl:when test="@code='h'">
                                    <!--  13381 Span class around subfield h so it can be suppressed via css -->
                                    <!-- <span class="title_medium"><xsl:apply-templates/> </span> -->
                                </xsl:when>
                                <xsl:when test="@code='c'">
                                    <!--  13381 Span class around subfield c so it can be suppressed via css -->
                                    <span class="title_resp_stmt"><xsl:apply-templates/> </span>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>: </xsl:text><xsl:apply-templates/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each>
                    </xsl:for-each>
                </h1>
            </xsl:when>
            <xsl:otherwise>
                <xsl:if test="marc:datafield[@tag=246 and @ind1='1' and @ind2 = '9']/marc:subfield[@code='a']">
                    <h1 class="title" property="name">
                        <xsl:text>[</xsl:text><xsl:value-of select="marc:datafield[@tag=246 and @ind1='1' and @ind2 = '9']/marc:subfield[@code='a']" /><xsl:text>] </xsl:text>
                    </h1>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </a>
    
    <xsl:if test="marc:datafield[@tag=100] or marc:datafield[@tag=110] or marc:datafield[@tag=111] or marc:datafield[@tag=700] or marc:datafield[@tag=710] or marc:datafield[@tag=711]">
        <p>
            <!-- Author Statement: Alternate Graphic Representation (MARC 880) -->
            <xsl:if test="$display880">
              <xsl:call-template name="m880Select">
              <xsl:with-param name="basetags">100,110,111,700,710,711</xsl:with-param>
              <xsl:with-param name="codes">abc</xsl:with-param>
              </xsl:call-template>
            </xsl:if>

            <xsl:choose>
            <xsl:when test="marc:datafield[@tag=100] or marc:datafield[@tag=110] or marc:datafield[@tag=111] or marc:datafield[@tag=700] or marc:datafield[@tag=710] or marc:datafield[@tag=711]">

            by <span class="author">
                <!-- #13383 -->
                <xsl:for-each select="marc:datafield[(@tag=100 or @tag=700 or @tag=110 or @tag=710 or @tag=111 or @tag=711) and @ind1!='z']">
                    <xsl:call-template name="chopPunctuation">
                        <xsl:with-param name="chopString">
                            <xsl:call-template name="subfieldSelect">
                                <xsl:with-param name="codes">
                                    <xsl:choose>
                                        <!-- #13383 include subfield e for field 111  -->
                                        <xsl:when test="@tag=111 or @tag=711">aeq</xsl:when>
                                        <xsl:when test="@tag=110 or @tag=710">ab</xsl:when>
                                        <xsl:otherwise>abcjq</xsl:otherwise>
                                    </xsl:choose>
                                </xsl:with-param>
                            </xsl:call-template>
                        </xsl:with-param>
                        <xsl:with-param name="punctuation">
                            <xsl:text>:,;/ </xsl:text>
                        </xsl:with-param>
                    </xsl:call-template>
                    <!-- Display title portion for 110 and 710 fields -->
                    <xsl:if test="(@tag=110 or @tag=710) and boolean(marc:subfield[@code='c' or @code='d' or @code='n' or @code='t'])">
                        <span class="titleportion">
                        <xsl:choose>
                            <xsl:when test="marc:subfield[@code='c' or @code='d' or @code='n'][not(marc:subfield[@code='t'])]"><xsl:text> </xsl:text></xsl:when>
                            <xsl:otherwise><xsl:text>. </xsl:text></xsl:otherwise>
                        </xsl:choose>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                            <xsl:call-template name="subfieldSelect">
                                <xsl:with-param name="codes">cdnt</xsl:with-param>
                            </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                        </span>
                    </xsl:if>
                    <!-- Display title portion for 111 and 711 fields -->
                    <xsl:if test="(@tag=111 or @tag=711) and boolean(marc:subfield[@code='c' or @code='d' or @code='g' or @code='n' or @code='t'])">
                            <span class="titleportion">
                            <xsl:choose>
                                <xsl:when test="marc:subfield[@code='c' or @code='d' or @code='g' or @code='n'][not(marc:subfield[@code='t'])]"><xsl:text> </xsl:text></xsl:when>
                                <xsl:otherwise><xsl:text>. </xsl:text></xsl:otherwise>
                            </xsl:choose>

                            <xsl:call-template name="chopPunctuation">
                                <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">cdgnt</xsl:with-param>
                                </xsl:call-template>
                                </xsl:with-param>
                            </xsl:call-template>
                            </span>
                    </xsl:if>
                    <!-- Display dates for 100 and 700 fields -->
                    <xsl:if test="(@tag=100 or @tag=700) and marc:subfield[@code='d']">
                        <span class="authordates">
                        <xsl:text>, </xsl:text>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                   <xsl:with-param name="codes">d</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                        </span>
                    </xsl:if>
                    <!-- Display title portion for 100 and 700 fields -->
                    <xsl:if test="@tag=700 and marc:subfield[@code='t']">
                        <span class="titleportion">
                        <xsl:text>. </xsl:text>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                        </span>
                    </xsl:if>
                    <!-- Display relators for 1XX and 7XX fields -->
                    <xsl:if test="marc:subfield[@code='4' or @code='e'][not(parent::*[@tag=111])] or (self::*[@tag=111] and marc:subfield[@code='4' or @code='j'][. != ''])">
                        <span class="relatorcode">
                            <xsl:text> [</xsl:text>
                            <xsl:choose>
                                <xsl:when test="@tag=111 or @tag=711">
                                    <xsl:choose>
                                        <!-- Prefer j over 4 for 111 and 711 -->
                                        <xsl:when test="marc:subfield[@code='j']">
                                            <xsl:for-each select="marc:subfield[@code='j']">
                                                <xsl:value-of select="."/>
                                                <xsl:if test="position() != last()">, </xsl:if>
                                            </xsl:for-each>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each select="marc:subfield[@code=4]">
                                                <xsl:value-of select="."/>
                                                <xsl:if test="position() != last()">, </xsl:if>
                                            </xsl:for-each>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:when>
                                <!-- Prefer e over 4 on 100 and 110 -->
                                <xsl:when test="marc:subfield[@code='e']">
                                    <xsl:for-each select="marc:subfield[@code='e'][not(@tag=111) or not(@tag=711)]">
                                        <xsl:value-of select="."/>
                                        <xsl:if test="position() != last()">, </xsl:if>
                                    </xsl:for-each>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:for-each select="marc:subfield[@code=4]">
                                        <xsl:value-of select="."/>
                                        <xsl:if test="position() != last()">, </xsl:if>
                                    </xsl:for-each>
                                </xsl:otherwise>
                            </xsl:choose>
                            <xsl:text>]</xsl:text>
                        </span>
                    </xsl:if>
                    <xsl:choose>
                        <xsl:when test="position()=last()"><xsl:text>.</xsl:text></xsl:when><xsl:otherwise><span class="separator"><xsl:text> | </xsl:text></span></xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>

            </span>
            </xsl:when>
            </xsl:choose>
        </p>
    </xsl:if>
    
    <xsl:if test="string-length($IncludeAdditionalMARCFields) > 0">
         <xsl:call-template name="additionalFields">
            <xsl:with-param name="marcFieldList" select="$IncludeAdditionalMARCFields"/>
        </xsl:call-template>
    </xsl:if>
    
        <!-- Availability line -->
        <span class="results_summary availability">
            <span class="label">Availability: </span>
            <xsl:variable name="sumAv" select="count(key('item-by-status', 'available'))"/>
            <xsl:variable name="sumRef" select="count(key('item-by-status', 'reference'))"/>

            <xsl:choose>
                <xsl:when test="$DivibibEnabled = 1 and marc:controlfield[@tag=003] = 'DE-Wi27'">
                    <span class="availabilityCheckDivibib"><xsl:attribute name="id"><xsl:text>Onleihe-</xsl:text><xsl:value-of select="marc:controlfield[@tag=001]"/></xsl:attribute><xsl:text>Checking availability </xsl:text><img src="https://cover.lmscloud.net/images/progress.gif" alt="Checking availability" /></span>
                </xsl:when>
                <xsl:when test="$itemcount=0">
                        <xsl:choose>
                            <xsl:when test="string-length($AlternateHoldingsField)=3 and marc:datafield[@tag=$AlternateHoldingsField]">
                            <xsl:variable name="AlternateHoldingsCount" select="count(marc:datafield[@tag=$AlternateHoldingsField])"/>
                            <xsl:for-each select="marc:datafield[@tag=$AlternateHoldingsField][1]">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes"><xsl:value-of select="$AlternateHoldingsSubfields"/></xsl:with-param>
                                    <xsl:with-param name="delimeter"><xsl:value-of select="$AlternateHoldingsSeparator"/></xsl:with-param>
                                </xsl:call-template>
                            </xsl:for-each>
                            (<xsl:value-of select="$AlternateHoldingsCount"/>)
                            </xsl:when>
                            <xsl:otherwise><span class="noitems">No items available.</span> </xsl:otherwise>
                        </xsl:choose>
                </xsl:when>
                <xsl:when test="$sumAv>0">
                   <span class="available reallyavailable">
                       <span class="AvailabilityLabel"><strong><xsl:text>Items available for loan: </xsl:text></strong></span>
                       <xsl:variable name="available_items"
                           select="key('item-by-status', 'available')"/>
                   <xsl:choose>
                   <xsl:when test="$singleBranchMode=1">
                        <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch))[1])]">
                           <span class="ItemSummary">
                               <xsl:value-of select="count(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch)))"/><xsl:text> </xsl:text>
                               <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber and $OPACItemLocation='callnum'">
                                   <span class="CallNumberAndLabel">
                                        <span class="LabelCallNumber">Call number: </span>
                                        <span class="CallNumber"><xsl:value-of select="items:itemcallnumber"/><xsl:if test="count(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch)))>1"><xsl:text>, ..</xsl:text></xsl:if></span>
                                   </span>
                               </xsl:if>
                               <xsl:choose>
                                   <xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when>
                                   <xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise>
                               </xsl:choose>
                            </span>
                        </xsl:for-each>
                   </xsl:when>
                   <xsl:otherwise>
                       <xsl:choose>
                            <xsl:when test="$OPACResultsLibrary='homebranch'">
                               <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch))[1])]">
                                   <span class="ItemSummary">
                                       <span class="ItemBranch"><xsl:value-of select="items:homebranch"/> </span>
                                       <xsl:text> (</xsl:text>
                                           <xsl:value-of select="count(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch)))"/>
                                       <xsl:text>) </xsl:text>
                                       <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber and $OPACItemLocation='callnum'">
                                           <span class="CallNumberAndLabel">
                                                <span class="LabelCallNumber">Call number: </span>
                                                <span class="CallNumber"><xsl:value-of select="items:itemcallnumber"/><xsl:if test="count(key('item-by-status-and-branch-holding', concat(items:status, ' ', items:holdingbranch)))>1"><xsl:text>, ..</xsl:text></xsl:if></span>
                                           </span>
                                       </xsl:if>
                                       <xsl:choose>
                                           <xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when>
                                           <xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise>
                                       </xsl:choose>
                                   </span>
                               </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                               <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch-holding', concat(items:status, ' ', items:holdingbranch))[1])]">
                                   <span class="ItemSummary">
                                       <span class="ItemBranch"><xsl:value-of select="items:holdingbranch"/> </span>
                                       <xsl:text> (</xsl:text>
                                           <xsl:value-of select="count(key('item-by-status-and-branch-holding', concat(items:status, ' ', items:holdingbranch)))"/>
                                       <xsl:text>) </xsl:text>
                                       <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber and $OPACItemLocation='callnum'">
                                           <span class="CallNumberAndLabel">
                                                <span class="LabelCallNumber">Call number: </span>
                                                <span class="CallNumber"><xsl:value-of select="items:itemcallnumber"/><xsl:if test="count(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch)))>1"><xsl:text>, ..</xsl:text></xsl:if></span>
                                           </span>
                                       </xsl:if>
                                       <xsl:choose>
                                           <xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when>
                                           <xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise>
                                       </xsl:choose>
                                   </span>
                               </xsl:for-each>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:otherwise>
                </xsl:choose>
                </span>
                </xsl:when>
            </xsl:choose>

            <xsl:choose>
                <xsl:when test="$sumRef>0">
                    <span class="available reference">
                       <span class="AvailabilityLabel"><strong><xsl:text>Items available for reference: </xsl:text></strong></span>
                        <xsl:variable name="reference_items" select="key('item-by-status', 'reference')"/>
                        <xsl:for-each select="$reference_items[generate-id() = generate-id(key('item-by-substatus-and-branch', concat(items:substatus, ' ', items:homebranch))[1])]">
                            <span>
                                <xsl:attribute name="class">
                                    ItemSummary
                                    <xsl:value-of select="translate(items:substatus,' ','_')"/>
                                </xsl:attribute>
                                <xsl:if test="$singleBranchMode=0">
                                    <span class="ItemBranch"><xsl:value-of select="items:homebranch"/><xsl:text> </xsl:text></span>
                                </xsl:if>
                                <span class='notforloandesc'><xsl:value-of select="items:substatus"/></span>
                                <xsl:text> (</xsl:text>
                                <xsl:value-of select="count(key('item-by-substatus-and-branch', concat(items:substatus, ' ', items:homebranch)))"/>
                                <xsl:text>) </xsl:text>
                                <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber and $OPACItemLocation='callnum'">
                                    <span class="CallNumberAndLabel">
                                        <span class="LabelCallNumber">Call number: </span>
                                        <span class="CallNumber"><xsl:value-of select="items:itemcallnumber"/><xsl:if test="count(key('item-by-substatus-and-branch', concat(items:substatus, ' ', items:homebranch)))>1"><xsl:text>, ..</xsl:text></xsl:if></span>
                                    </span>
                                </xsl:if>
                                <xsl:choose><xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when><xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise></xsl:choose>
                            </span>
                        </xsl:for-each>
                    </span>
                </xsl:when>
            </xsl:choose>

            <xsl:choose>
                <xsl:when test="number($sumAv+$sumRef) &lt; number($itemcount)">
                    <span class="unavailable">
                        <span class="AvailabilityLabel"><strong><xsl:text>Not available: </xsl:text></strong></span>

                        <!-- First the remaining not for loan categories -->
                        <xsl:variable name="unavailable_items" select="key('item-by-status', 'reallynotforloan')"/>
                        <xsl:for-each select="$unavailable_items[not(./items:substatus=preceding-sibling::*/items:substatus)]">
                            <span class="ItemSummary unavailable">
                                <span class='notforloandesc'><xsl:value-of select="items:substatus"/></span>
                                <xsl:text> (</xsl:text>
                                <xsl:value-of select="count(parent::*/items:item/items:substatus[ text() = current()/items:substatus  ])"/>
                                <xsl:text>)</xsl:text>
                                <xsl:choose><xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when><xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise></xsl:choose>
                            </span>
                        </xsl:for-each>

                        <!-- Followed by other statuses -->
                        <xsl:if test="count(key('item-by-status', 'Checked out'))>0">
                            <span class="unavailable">
                                <xsl:text>Checked out (</xsl:text>
                                <xsl:value-of select="count(key('item-by-status', 'Checked out'))"/>
                                <xsl:text>). </xsl:text>
                            </span>
                        </xsl:if>
                        <xsl:if test="count(key('item-by-status', 'Withdrawn'))>0">
                            <span class="unavailable">
                                <xsl:text>Withdrawn (</xsl:text>
                                <xsl:value-of select="count(key('item-by-status', 'Withdrawn'))"/>
                                <xsl:text>). </xsl:text>
                            </span>
                        </xsl:if>
                        <xsl:if test="$hidelostitems='0' and count(key('item-by-status', 'Lost'))>0">
                            <span class="unavailable">
                                <xsl:text>Lost (</xsl:text>
                                <xsl:value-of select="count(key('item-by-status', 'Lost'))"/>
                                <xsl:text>). </xsl:text>
                            </span>
                        </xsl:if>
                        <xsl:if test="count(key('item-by-status', 'Damaged'))>0">
                            <span class="unavailable">
                                <xsl:text>Damaged (</xsl:text>
                                <xsl:value-of select="count(key('item-by-status', 'Damaged'))"/>
                                <xsl:text>). </xsl:text>
                            </span>
                        </xsl:if>
                        <xsl:if test="count(key('item-by-status', 'Pending hold'))>0">
                            <span class="unavailable">
                                <xsl:text>Pending hold (</xsl:text>
                                <xsl:value-of select="count(key('item-by-status', 'Pending hold'))"/>
                                <xsl:text>). </xsl:text>
                            </span>
                        </xsl:if>
                        <xsl:if test="count(key('item-by-status', 'In transit'))>0">
                            <span class="unavailable">
                                <xsl:text>In transit (</xsl:text>
                                <xsl:value-of select="count(key('item-by-status', 'In transit'))"/>
                                <xsl:text>). </xsl:text>
                            </span>
                        </xsl:if>
                        <xsl:if test="count(key('item-by-status', 'Waiting'))>0">
                            <span class="unavailable">
                                <xsl:text>On hold (</xsl:text>
                                <xsl:value-of select="count(key('item-by-status', 'Waiting'))"/>
                                <xsl:text>). </xsl:text>
                            </span>
                        </xsl:if>
                    </span>
                </xsl:when>
            </xsl:choose>
        </span>
        <!-- End of Availability line -->

        <!-- Location line -->
        <xsl:choose>
            <xsl:when test="($OPACItemLocation='location' or $OPACItemLocation='ccode') and (count(key('item-by-status', 'available'))!=0 or count(key('item-by-status', 'reference'))!=0)">
                <span class="results_summary location">

                <xsl:choose>
                    <xsl:when test="$OPACItemLocation='location'">
                        <span class="label">Location(s): </span>
                    </xsl:when>
                    <xsl:when test="$OPACItemLocation='ccode'">
                        <span class="label">Collection(s): </span>
                    </xsl:when>
                </xsl:choose>

                <xsl:choose>
                <xsl:when test="count(key('item-by-status', 'available'))>0">
                    <span class="available">
                        <xsl:variable name="available_items" select="key('item-by-status', 'available')"/>
                        <xsl:for-each select="$available_items[generate-id() = generate-id(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch))[1])]">
                            <xsl:choose>
                                <xsl:when test="$OPACItemLocation='location'"><strong><xsl:value-of select="concat(items:location,' ')"/></strong></xsl:when>
                                <xsl:when test="$OPACItemLocation='ccode'"><strong><xsl:value-of select="concat(items:ccode,' ')"/></strong></xsl:when>
                            </xsl:choose>
                            <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber">
                                <span class="CallNumberAndLabel">
                                    <span class="LabelCallNumber">Call number: </span>
                                    <span class="CallNumber"><xsl:value-of select="items:itemcallnumber"/></span>
                                </span>
                            </xsl:if>
                            <xsl:choose><xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when><xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise></xsl:choose>
                        </xsl:for-each>
                    </span>
                </xsl:when>
                <xsl:when test="count(key('item-by-status', 'reference'))>0">
                    <span class="available">
                        <xsl:variable name="reference_items" select="key('item-by-status', 'reference')"/>
                        <xsl:for-each select="$reference_items[generate-id() = generate-id(key('item-by-status-and-branch-home', concat(items:status, ' ', items:homebranch))[1])]">
                            <xsl:choose>
                                <xsl:when test="$OPACItemLocation='location'"><strong><xsl:value-of select="concat(items:location,' ')"/></strong></xsl:when>
                                <xsl:when test="$OPACItemLocation='ccode'"><strong><xsl:value-of select="concat(items:ccode,' ')"/></strong></xsl:when>
                            </xsl:choose>
                            <xsl:if test="items:itemcallnumber != '' and items:itemcallnumber">
                                <span class="CallNumberAndLabel">
                                    <span class="LabelCallNumber">Call number: </span>
                                    <span class="CallNumber"><xsl:value-of select="items:itemcallnumber"/></span>
                                </span>
                            </xsl:if>
                            <xsl:choose><xsl:when test="position()=last()"><xsl:text>. </xsl:text></xsl:when><xsl:otherwise><xsl:text>, </xsl:text></xsl:otherwise></xsl:choose>
                        </xsl:for-each>
                    </span>
                </xsl:when>
                </xsl:choose>
                </span>
            </xsl:when>
        </xsl:choose>
        <!-- End of Location line -->
    </xsl:template>

    <xsl:template name="nameABCQ">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abcq</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
                <xsl:with-param name="punctuation">
                    <xsl:text>:,;/ </xsl:text>
                </xsl:with-param>
            </xsl:call-template>
    </xsl:template>

    <xsl:template name="nameABCDN">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">abcdn</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
                <xsl:with-param name="punctuation">
                    <xsl:text>:,;/ </xsl:text>
                </xsl:with-param>
            </xsl:call-template>
    </xsl:template>

    <xsl:template name="nameACDEQ">
            <xsl:call-template name="subfieldSelect">
                <xsl:with-param name="codes">acdeq</xsl:with-param>
            </xsl:call-template>
    </xsl:template>

    <xsl:template name="nameDate">
        <xsl:for-each select="marc:subfield[@code='d']">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString" select="."/>
            </xsl:call-template>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="role">
        <xsl:for-each select="marc:subfield[@code='e']">
                    <xsl:value-of select="."/>
        </xsl:for-each>
        <xsl:for-each select="marc:subfield[@code='4']">
                    <xsl:value-of select="."/>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="specialSubfieldSelect">
        <xsl:param name="anyCodes"/>
        <xsl:param name="axis"/>
        <xsl:param name="beforeCodes"/>
        <xsl:param name="afterCodes"/>
        <xsl:variable name="str">
            <xsl:for-each select="marc:subfield">
                <xsl:if test="contains($anyCodes, @code) or (contains($beforeCodes,@code) and following-sibling::marc:subfield[@code=$axis]) or (contains($afterCodes,@code) and preceding-sibling::marc:subfield[@code=$axis])">
                    <xsl:value-of select="text()"/>
                    <xsl:text> </xsl:text>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="substring($str,1,string-length($str)-1)"/>
    </xsl:template>

    <xsl:template name="subtitle">
        <xsl:if test="marc:subfield[@code='b']">
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString">
                        <xsl:value-of select="marc:subfield[@code='b']"/>

                        <!--<xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">b</xsl:with-param>
                        </xsl:call-template>-->
                    </xsl:with-param>
                </xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template name="chopBrackets">
        <xsl:param name="chopString"></xsl:param>
        <xsl:variable name="string">
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString" select="$chopString"></xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="substring($string, 1,1)='['">
            <xsl:value-of select="substring($string,2, string-length($string)-2)"></xsl:value-of>
        </xsl:if>
        <xsl:if test="substring($string, 1,1)!='['">
            <xsl:value-of select="$string"></xsl:value-of>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="additionalFields">
        <xsl:param name="marcFieldList" select="." />
        <xsl:if test="string-length($marcFieldList) > 0">
            <xsl:variable name="marcContentField" select="substring-before(concat($marcFieldList, '|'), '|')"/>
            <xsl:if test="string-length($marcContentField) > 0">
                <xsl:variable name="marcField">
                    <xsl:choose>
                        <xsl:when test="substring-before(concat($marcContentField,'='),'=') != $marcContentField">
                            <xsl:value-of select="substring-before($marcContentField,'=')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$marcContentField"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="fieldName">
                    <xsl:choose>
                        <xsl:when test="substring-before(concat($marcContentField,'='),'=') != $marcContentField">
                            <xsl:value-of select="substring-after($marcContentField,'=')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text></xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="subfields">
                    <xsl:choose>
                        <xsl:when test="substring-before(concat($marcField,'&#36;'),'&#36;') != $marcField">
                            <xsl:value-of select="substring-after($marcField,'&#36;')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>a</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="useField">
                    <xsl:choose>
                        <xsl:when test="substring-before(concat($marcField,'&#36;'),'&#36;') != $marcField">
                            <xsl:value-of select="substring-before($marcField,'&#36;')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$marcField"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:if test="marc:datafield[@tag=$useField and marc:subfield[contains($subfields, @code)] ]">
                    <div class="results_summary additionalfield">
                    <xsl:if test="string-length($fieldName) > 0">
                        <span class="label"><xsl:value-of select="$fieldName" />: </span>
                    </xsl:if>
                    <xsl:for-each select="marc:datafield[@tag=$useField and marc:subfield[contains($subfields, @code)]]">
                        <xsl:if test="position() != 1"><xsl:text> | </xsl:text></xsl:if>
                            <xsl:call-template name="subfieldSelect">
                                <xsl:with-param name="codes"><xsl:value-of select="$subfields"/></xsl:with-param>
                                <xsl:with-param name="delimeter"> | </xsl:with-param>
                            </xsl:call-template>
                    </xsl:for-each>
                    </div>
                </xsl:if>
                
            </xsl:if>
            <xsl:call-template name="additionalFields">
                <xsl:with-param name="marcFieldList" select="substring-after($marcFieldList, '|')"/>
            </xsl:call-template>
        </xsl:if>
     </xsl:template>

</xsl:stylesheet>
