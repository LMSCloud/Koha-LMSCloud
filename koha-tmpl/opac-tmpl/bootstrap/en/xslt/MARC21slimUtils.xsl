<?xml version='1.0'?>
<!DOCTYPE stylesheet>
<xsl:stylesheet version="1.0"
  xmlns:marc="http://www.loc.gov/MARC21/slim"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:str="http://exslt.org/strings"
  exclude-result-prefixes="marc str">
  <xsl:include href="MARC21Languages.xsl"/>
    <!-- Characters we'll support. We could add control chars 0-31 and 127-159, but we won't. -->
    <xsl:variable name="ascii"> !"#$%&amp;'()*+,-./0123456789:;&lt;=&gt;?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~</xsl:variable>
    <xsl:variable name="latin1">&#160;&#161;&#162;&#163;&#164;&#165;&#166;&#167;&#168;&#169;&#170;&#171;&#172;&#173;&#174;&#175;&#176;&#177;&#178;&#179;&#180;&#181;&#182;&#183;&#184;&#185;&#186;&#187;&#188;&#189;&#190;&#191;&#192;&#193;&#194;&#195;&#196;&#197;&#198;&#199;&#200;&#201;&#202;&#203;&#204;&#205;&#206;&#207;&#208;&#209;&#210;&#211;&#212;&#213;&#214;&#215;&#216;&#217;&#218;&#219;&#220;&#221;&#222;&#223;&#224;&#225;&#226;&#227;&#228;&#229;&#230;&#231;&#232;&#233;&#234;&#235;&#236;&#237;&#238;&#239;&#240;&#241;&#242;&#243;&#244;&#245;&#246;&#247;&#248;&#249;&#250;&#251;&#252;&#253;&#254;&#255;</xsl:variable>

    <!-- Characters that usually don't need to be escaped -->
    <xsl:variable name="safe">!'()*-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~&#192;&#193;&#196;&#200;&#201;&#210;&#211;&#214;&#220;&#223;&#224;&#225;&#228;&#232;&#233;&#242;&#243;&#246;&#252;</xsl:variable>
    <xsl:variable name="hex" >0123456789ABCDEF</xsl:variable>

    <xsl:template name="url-encode">
        <xsl:param name="str"/>   
        <xsl:if test="$str">
            <xsl:variable name="first-char" select="substring($str,1,1)"/>
            <xsl:choose>
                <xsl:when test="contains($safe,$first-char)">
                    <xsl:value-of select="$first-char"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="codepoint">
                        <xsl:choose>
                            <xsl:when test="contains($ascii,$first-char)">
                                <xsl:value-of select="string-length(substring-before($ascii,$first-char)) + 32"/>
                            </xsl:when>
                            <xsl:when test="contains($latin1,$first-char)">
                                <xsl:value-of select="string-length(substring-before($latin1,$first-char)) + 160"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:message terminate="no">Warning: string contains a character that is out of range! Substituting "?".</xsl:message>
                                <xsl:text>63</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="hex-digit1" select="substring($hex,floor($codepoint div 16) + 1,1)"/>
                    <xsl:variable name="hex-digit2" select="substring($hex,$codepoint mod 16 + 1,1)"/>
                    <xsl:value-of select="concat('%',$hex-digit1,$hex-digit2)"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="string-length($str) &gt; 1">
                <xsl:call-template name="url-encode">
                    <xsl:with-param name="str" select="substring($str,2)"/>
                </xsl:call-template>
            </xsl:if>
        </xsl:if>
    </xsl:template>

	<xsl:template name="datafield">
		<xsl:param name="tag"/>
		<xsl:param name="ind1"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="ind2"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="subfields"/>
		<xsl:element name="datafield">
			<xsl:attribute name="tag">
				<xsl:value-of select="$tag"/>
			</xsl:attribute>
			<xsl:attribute name="ind1">
				<xsl:value-of select="$ind1"/>
			</xsl:attribute>
			<xsl:attribute name="ind2">
				<xsl:value-of select="$ind2"/>
			</xsl:attribute>
			<xsl:copy-of select="$subfields"/>
		</xsl:element>
	</xsl:template>

	<xsl:template name="subfieldSelect">
		<xsl:param name="codes"/>
		<xsl:param name="delimeter"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="subdivCodes"/>
		<xsl:param name="subdivDelimiter"/>
        <xsl:param name="prefix"/>
        <xsl:param name="suffix"/>
        <xsl:param name="urlencode"/>
		<xsl:variable name="str">
			<xsl:for-each select="marc:subfield">
				<xsl:if test="contains($codes, @code)">
                    <xsl:if test="contains($subdivCodes, @code)">
                        <xsl:value-of select="$subdivDelimiter"/>
                    </xsl:if>
					<xsl:value-of select="$prefix"/><xsl:value-of select="translate(text(),'&#x0098;&#x009c;','')"/><xsl:value-of select="$suffix"/><xsl:value-of select="$delimeter"/>
				</xsl:if>
			</xsl:for-each>
		</xsl:variable>
        <xsl:choose>
            <xsl:when test="$urlencode=1">
                <xsl:value-of select="str:encode-uri(translate(substring($str,1,string-length($str)-string-length($delimeter)),'&#x0098;&#x009c;',''), true())"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="translate(substring($str,1,string-length($str)-string-length($delimeter)),'&#x0098;&#x009c;','')"/>
            </xsl:otherwise>
        </xsl:choose>
	</xsl:template>

    <xsl:template name="subfieldSelectSpan">
        <xsl:param name="codes"/>
        <xsl:param name="delimeter"><xsl:text> </xsl:text></xsl:param>
        <xsl:param name="subdivCodes"/>
        <xsl:param name="subdivDelimiter"/>
        <xsl:param name="prefix"/>
        <xsl:param name="suffix"/>
        <xsl:param name="newline"/>
            <xsl:for-each select="marc:subfield">
                <xsl:if test="contains($codes, @code)">
                    <span>
                        <xsl:attribute name="class">
                            <xsl:value-of select="@code"/>
                            <xsl:if test="$newline = 1 and contains(text(), '--')">
                                <xsl:text> newline</xsl:text>
                            </xsl:if>
                        </xsl:attribute>
                        <xsl:if test="contains($subdivCodes, @code)">
                            <xsl:value-of select="$subdivDelimiter"/>
                        </xsl:if>
                        <xsl:value-of select="$prefix"/><xsl:value-of select="translate(text(),'&#x0098;&#x009c;','')"/><xsl:value-of select="$suffix"/><xsl:if test="position()!=last()"><xsl:value-of select="$delimeter"/></xsl:if>
                    </span>
                </xsl:if>
            </xsl:for-each>
    </xsl:template>

	<xsl:template name="buildSpaces">
		<xsl:param name="spaces"/>
		<xsl:param name="char"><xsl:text> </xsl:text></xsl:param>
		<xsl:if test="$spaces>0">
			<xsl:value-of select="$char"/>
			<xsl:call-template name="buildSpaces">
				<xsl:with-param name="spaces" select="$spaces - 1"/>
				<xsl:with-param name="char" select="$char"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

  <xsl:template name="buildBiblioDefaultViewURL">
    <xsl:param name="BiblioDefaultView"/>
    <xsl:choose>
        <xsl:when test="$BiblioDefaultView='normal'">
            <xsl:text>/cgi-bin/koha/opac-detail.pl?biblionumber=</xsl:text>
        </xsl:when>
        <xsl:when test="$BiblioDefaultView='isbd'">
            <xsl:text>/cgi-bin/koha/opac-ISBDdetail.pl?biblionumber=</xsl:text>
        </xsl:when>
        <xsl:when test="$BiblioDefaultView='marc'">
            <xsl:text>/cgi-bin/koha/opac-MARCdetail.pl?biblionumber=</xsl:text>
        </xsl:when>
        <xsl:otherwise>
            <xsl:text>/cgi-bin/koha/opac-detail.pl?biblionumber=</xsl:text>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

	<xsl:template name="chopPunctuation">
		<xsl:param name="chopString"/>
		<xsl:variable name="length" select="string-length($chopString)"/>
		<xsl:choose>
			<xsl:when test="$length=0"/>
			<xsl:when test="contains(':,;/ ', substring($chopString,$length,1))">
				<xsl:call-template name="chopPunctuation">
					<xsl:with-param name="chopString" select="substring($chopString,1,$length - 1)"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="not($chopString)"/>
			<xsl:otherwise><xsl:value-of select="$chopString"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- Function extractControlNumber is used to extract the control number (record number) from MARC tags 773/80/85 [etc.] subfield $w.
	     Parameter: control number string.
	     Assumes LOC convention: (OrgCode)recordNumber.
	     If OrgCode is not present, return full string.
	     Additionally, handle various brackets/parentheses. Chop leading and trailing spaces.
         Returns the value URI-encoded.
	-->
	<xsl:template name="extractControlNumber">
	    <xsl:param name="subfieldW"/>
	    <xsl:variable name="tranW" select="translate($subfieldW,']})&gt;','))))')"/>
	    <xsl:choose>
	      <xsl:when test="contains($tranW,')')">
	        <xsl:value-of select="str:encode-uri(normalize-space(translate(substring-after($tranW,')'),'[]{}()&lt;&gt;','')), true())"/>
	      </xsl:when>
	      <xsl:otherwise>
	        <xsl:value-of select="str:encode-uri(normalize-space($subfieldW), true())"/>
	      </xsl:otherwise>
	    </xsl:choose>
	</xsl:template>

    <!-- Function m880Select:  Display Alternate Graphic Representation (MARC 880) for selected latin "base"tags
        - should be called immediately before the corresonding latin tags are processed
        - tags in right-to-left languages are displayed floating right
        * Parameter:
           + basetags: display these tags if found in linkage section ( subfield 6) of tag 880
           + codes: display these subfields codes
        * Options:
            - class: wrap output in <span class="$class">...</span>
            - label: prefix each(!) tag with label $label
            - bibno: link to biblionumber $bibno
            - index: build a search link using index $index with subfield $a as key; if subfield $9 is present use index 'an' with key $9 instead.
         * Limitations:
            - displays every field on a separate line (to switch between rtl and ltr)
         * Pitfalls:
           (!) output might be empty
    -->
    <xsl:template name="m880Select">
         <xsl:param name="basetags"/> <!-- e.g.  100,700,110,710 -->
        <xsl:param name="codes"/> <!-- e.g. abc  -->
        <xsl:param name="class"/> <!-- e.g. results_summary -->
        <xsl:param name="label"/> <!-- e.g.  Edition -->
        <xsl:param name="bibno"/>
        <xsl:param name="index"/> <!-- e.g.  au -->

        <xsl:for-each select="marc:datafield[@tag=880]">
            <xsl:variable name="code6" select="marc:subfield[@code=6]"/>
            <xsl:if test="contains(string($basetags), substring($code6,1,3))">
                <span>
                    <xsl:choose>
                    <xsl:when test="boolean($class) and substring($code6,string-length($code6)-1,2) ='/r'">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/> m880</xsl:attribute>
                        <xsl:attribute name="dir">rtl</xsl:attribute>
                    </xsl:when>
                     <xsl:when test="boolean($class)">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
                        <xsl:attribute name="style">display:block; </xsl:attribute>
                    </xsl:when>
                     <xsl:when test="substring($code6,string-length($code6)-1,2) ='/r'">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/> m880</xsl:attribute>
                    </xsl:when>
                    </xsl:choose>
                    <xsl:if test="boolean($label)">
                        <span class="label">
                            <xsl:value-of select="$label"/>
                        </span>
                    </xsl:if>
                    <xsl:variable name="str">
                        <xsl:for-each select="marc:subfield">
                            <xsl:if test="contains($codes, @code)">
                                <xsl:value-of select="text()"/>
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:if test="string-length($str) &gt; 0">
                        <xsl:choose>
                            <xsl:when test="boolean($bibno)">
                                <a>
                                    <xsl:attribute name="href">/cgi-bin/koha/opac-detail.pl?biblionumber=<xsl:value-of  select="str:encode-uri($bibno, true())"/></xsl:attribute>
                                    <xsl:value-of select="$str"/>
                                </a>
                            </xsl:when>
                           <xsl:when test="boolean($index) and boolean(marc:subfield[@code=9])">
                                <a>
                                    <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=an:<xsl:value-of  select="str:encode-uri(marc:subfield[@code=9], true())"/></xsl:attribute>
                                    <xsl:value-of select="$str"/>
                                </a>
                            </xsl:when>
                            <xsl:when test="boolean($index)">
                                <a>
                                    <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:value-of select="str:encode-uri($index, true())"/>:<xsl:value-of select="str:encode-uri(marc:subfield[@code='a'], true())"/></xsl:attribute>
                                    <xsl:value-of select="$str"/>
                                </a>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$str"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>
                </span>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="showRDAtag264">
        <!-- Function showRDAtag264 shows selected information from tag 264
         on the Publisher line (used by OPAC Detail and Results)
         Depending on how many tags you have, we will pick by preference
         Publisher-latest or Publisher or 'Other'-latest or 'Other'
         The preferred tag is saved in the fav variable and passed to a
         helper named-template -->
        <!-- Amended  to show all 264 fields (filtered by ind1=3 if ind1=3 is present in the record)  -->
        <xsl:param name="show_url"/>
        <xsl:choose>
            <xsl:when test="marc:datafield[@tag=264 and @ind1=3]">
                <xsl:for-each select="marc:datafield[@tag=264 and @ind1=3]">
                    <xsl:call-template name="showRDAtag264helper">
                        <xsl:with-param name="field" select="."/>
                        <xsl:with-param name="url" select="$show_url"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="marc:datafield[@tag=264]">
                    <xsl:call-template name="showRDAtag264helper">
                        <xsl:with-param name="field" select="."/>
                        <xsl:with-param name="url" select="$show_url"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="showRDAtag264helper">
        <xsl:param name="field"/>
        <xsl:param name="url"/>
        <xsl:variable name="ind2" select="$field/@ind2"/>
        <span class="results_summary rda264">
            <xsl:choose>
                <xsl:when test="$ind2='0'">
                    <span class="label">Producer: </span>
                </xsl:when>
                <xsl:when test="$ind2='1'">
                    <span class="label">Publisher: </span>
                </xsl:when>
                <xsl:when test="$ind2='2'">
                    <span class="label">Distributor: </span>
                </xsl:when>
                <xsl:when test="$ind2='3'">
                    <span class="label">Manufacturer: </span>
                </xsl:when>
                <xsl:when test="$ind2='4'">
                    <span class="label">Copyright date: </span>
                </xsl:when>
            </xsl:choose>

            <xsl:if test="$field/marc:subfield[@code='a']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">a</xsl:with-param>
                </xsl:call-template>
            </xsl:if>
            <xsl:text> </xsl:text>

            <xsl:choose>
                <xsl:when test="$url='1'">
                    <xsl:if test="$field/marc:subfield[@code='b']">
                         <a>
                         <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=Provider:<xsl:value-of select="str:encode-uri($field/marc:subfield[@code='b'], true())"/></xsl:attribute>
                         <xsl:call-template name="subfieldSelect">
                             <xsl:with-param name="codes">b</xsl:with-param>
                         </xsl:call-template>
                         </a>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if test="$field/marc:subfield[@code='b']">
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">b</xsl:with-param>
                        </xsl:call-template>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:text> </xsl:text>
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">c</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>
        </span>
    </xsl:template>

    <xsl:template name="show-lang-041">
      <xsl:if test="marc:datafield[@tag=041]">
    <xsl:for-each select="marc:datafield[@tag=041]">
        <span class="results_summary languages">
        <xsl:call-template name="show-lang-node">
            <xsl:with-param name="langNode" select="marc:subfield[@code='a']"/>
            <xsl:with-param name="langLabel">Language: </xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="show-lang-node">
            <xsl:with-param name="langNode" select="marc:subfield[@code='b']"/>
            <xsl:with-param name="langLabel">Summary language: </xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="show-lang-node">
            <xsl:with-param name="langNode" select="marc:subfield[@code='d']"/>
            <xsl:with-param name="langLabel">Spoken language: </xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="show-lang-node">
            <xsl:with-param name="langNode" select="marc:subfield[@code='h']"/>
            <xsl:with-param name="langLabel">Original language: </xsl:with-param>
        </xsl:call-template>
        <xsl:call-template name="show-lang-node">
            <xsl:with-param name="langNode" select="marc:subfield[@code='j']"/>
            <xsl:with-param name="langLabel">Subtitle language: </xsl:with-param>
        </xsl:call-template>
        </span>
    </xsl:for-each>
      </xsl:if>
    </xsl:template>

    <xsl:template name="show-lang-node">
      <xsl:param name="langNode"/>
      <xsl:param name="langLabel"/>
      <xsl:if test="$langNode">
    <span class="language">
        <span class="label"><xsl:value-of select="$langLabel"/></span>
        <xsl:for-each select="$langNode">
        <span>
            <xsl:attribute name="class">lang_code-<xsl:value-of select="translate(., ' .-;|#', '_')"/></xsl:attribute>
            <xsl:call-template name="languageCodeText">
        <xsl:with-param name="code" select="."/>
            </xsl:call-template>
            <xsl:if test="position() != last()">
            <span class="separator"><xsl:text>, </xsl:text></span>
            </xsl:if>
        </span>
        </xsl:for-each>
        <span class="separator"><xsl:text> </xsl:text></span>
    </span>
      </xsl:if>
    </xsl:template>

    <xsl:template name="show-series">
        <xsl:param name="searchurl"/>
        <xsl:param name="UseControlNumber"/>
        <xsl:param name="UseAuthoritiesForTracings"/>
        <!-- Series -->
        <xsl:if test="marc:datafield[@tag=440 or @tag=490 or @tag=800 or @tag=810 or @tag=811 or @tag=830]">
        <span class="results_summary series"><span class="label">Series: </span>
        <!-- 440 -->
        <xsl:for-each select="marc:datafield[@tag=440 and @ind1!='z']">
            <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=se,phr:"<xsl:value-of select="str:encode-uri(str:replace(marc:subfield[@code='a'],'?','\?'), true())"/>"</xsl:attribute>
                <xsl:call-template name="chopPunctuation">
                    <xsl:with-param name="chopString">
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">a</xsl:with-param>
                        </xsl:call-template>
                    </xsl:with-param>
                </xsl:call-template>
            </a>
            <xsl:call-template name="part"/>
            <xsl:if test="marc:subfield[@code='v']">
                <xsl:text> ; </xsl:text><xsl:value-of select="marc:subfield[@code='v']" />
            </xsl:if>
            <xsl:choose>
                <xsl:when test="position()=last()">
                    <xsl:if test="../marc:datafield[@tag=490][@ind1!=1] or (../marc:datafield[@tag=490][@ind1=1] and ../marc:datafield[(@tag=800 or @tag=810 or @tag=811 or @tag=830) and @ind1!='z'])">
                        <span class="separator"> | </span>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise><span class="separator"> | </span></xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>

        <!-- 490 Series not traced, Ind1 = 0 -->
        <xsl:for-each select="marc:datafield[@tag=490][not(@ind1=1 and count(../marc:datafield[(@tag=800 or @tag=810 or @tag=811 or @tag=830) and @ind1!='z']) &gt; 0)]">
            <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=se:(<xsl:value-of select="str:encode-uri(str:replace(marc:subfield[@code='a'],'?','\?'), true())"/>)</xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
            </a>
            <xsl:call-template name="part"/>
            <xsl:if test="marc:subfield[@code='v']">
                <xsl:text> ; </xsl:text><xsl:value-of select="marc:subfield[@code='v']" />
            </xsl:if>
            <xsl:choose>
                <xsl:when test="position()=last()">
                    <xsl:if test="../marc:datafield[@tag=490][@ind1=1] and (../marc:datafield[(@tag=800 or @tag=810 or @tag=811) and @ind1!='z'] or ../marc:datafield[@tag=830 and @ind1!='z'])">
                        <span class="separator"> | </span>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise><span class="separator"> | </span></xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>

        <xsl:if test="marc:datafield[@tag=490][@ind1=1]">
        <!-- 800,810,811,830 always display. -->
        <xsl:for-each select="marc:datafield[(@tag=800 or @tag=810 or @tag=811) and @ind1!='z']">
            <xsl:choose>
                <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                    <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=rcn:<xsl:value-of select="str:encode-uri(marc:subfield[@code='w'], true())"/></xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a_t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                    </a>
                </xsl:when>
                <xsl:when test="marc:subfield[@code=9] and $UseAuthoritiesForTracings='1'">
                    <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=an:<xsl:value-of select="str:encode-uri(marc:subfield[@code=9], true())"/></xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a_t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=se:("<xsl:value-of select="str:encode-uri(marc:subfield[@code='t'], true())"/>)&amp;q=au:"<xsl:value-of select="str:encode-uri(marc:subfield[@code='a'], true())"/>"</xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a_t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                    </a>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:call-template name="part"/>
            <xsl:text> ; </xsl:text>
            <xsl:value-of  select="marc:subfield[@code='v']" />
        <xsl:choose>
            <xsl:when test="position()=last()">
                <xsl:if test="../marc:datafield[@tag=830 and @ind1!='z']">
                    <span class="separator"> | </span>
                </xsl:if>
            </xsl:when>
            <xsl:otherwise>
                <span class="separator"> | </span>
            </xsl:otherwise>
        </xsl:choose>
        </xsl:for-each>

        <xsl:for-each select="marc:datafield[@tag=830 and @ind1!='z']">
            <xsl:choose>
                <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                    <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=rcn:<xsl:value-of select="marc:subfield[@code='w']"/></xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a_t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                    </a>
                </xsl:when>
                <xsl:when test="marc:subfield[@code=9] and $UseAuthoritiesForTracings='1'">
                    <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=an:<xsl:value-of select="str:encode-uri(marc:subfield[@code=9], true())"/></xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a_t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <a><xsl:attribute name="href"><xsl:value-of select="$searchurl"/>?q=se:("<xsl:value-of select="str:encode-uri(str:replace(marc:subfield[@code='t'],'?','\?'), true())"/>)</xsl:attribute>
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a_t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                    </a>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:call-template name="part"/>
            <xsl:if test="marc:subfield[@code='v']">
                <xsl:text> ; </xsl:text><xsl:value-of select="marc:subfield[@code='v']" />
            </xsl:if>
        <xsl:choose><xsl:when test="position()=last()"><xsl:text></xsl:text></xsl:when><xsl:otherwise><span class="separator"> | </span></xsl:otherwise></xsl:choose>
        </xsl:for-each>
        </xsl:if>

        </span>
        </xsl:if>
    </xsl:template>

    <xsl:template name="part">
        <xsl:variable name="partNumber">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">n</xsl:with-param>
                <xsl:with-param name="anyCodes">n</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="partName">
            <xsl:call-template name="specialSubfieldSelect">
                <xsl:with-param name="axis">p</xsl:with-param>
                <xsl:with-param name="anyCodes">p</xsl:with-param>
                <xsl:with-param name="afterCodes">fghkdlmor</xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="string-length(normalize-space($partNumber)) or string-length(normalize-space($partName))" >
            <xsl:text>. </xsl:text>
        </xsl:if>
        <xsl:if test="string-length(normalize-space($partNumber))">
            <xsl:value-of select="$partNumber" />
        </xsl:if>
        <xsl:if test="string-length(normalize-space($partNumber))"><xsl:text> </xsl:text></xsl:if>
        <xsl:if test="string-length(normalize-space($partName))">
            <xsl:value-of select="$partName" />
        </xsl:if>
    </xsl:template>

    <xsl:template name="quote_search_term">
        <xsl:param name="term" />
        <xsl:text>"</xsl:text>
        <xsl:call-template name="escape_quotes">
            <xsl:with-param name="text">
                <xsl:value-of select="$term"/>
            </xsl:with-param>
        </xsl:call-template>
        <xsl:text>"</xsl:text>
    </xsl:template>

    <xsl:template name="escape_quotes">
        <xsl:param name="text"/>
        <xsl:choose>
            <xsl:when test="contains($text, '&quot;')">
                <xsl:variable name="before" select="substring-before($text,'&quot;')"/>
                <xsl:variable name="next" select="substring-after($text,'&quot;')"/>
                <xsl:value-of select="$before"/>
                <xsl:text>\&quot;</xsl:text>
                <xsl:call-template name="escape_quotes">
                    <xsl:with-param name="text" select="$next"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$text"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="host-item-entries">
        <xsl:param name="UseControlNumber"/>
        <!-- 773 -->
        <xsl:if test="marc:datafield[@tag=773]">
            <xsl:for-each select="marc:datafield[@tag=773]">
                <xsl:if test="@ind1 !=1">
                    <span class="results_summary in"><span class="label">
                    <xsl:choose>
                        <xsl:when test="@ind2=' '">
                            In:
                        </xsl:when>
                        <xsl:when test="@ind2=8 and marc:subfield[@code='i']">
                            <xsl:call-template name="subfieldSelect">
                                <xsl:with-param name="codes">i</xsl:with-param>
                            </xsl:call-template>
                            <xsl:text> </xsl:text>
                        </xsl:when>
                    </xsl:choose>
                    </span>
                    <xsl:variable name="f773">
                        <xsl:call-template name="chopPunctuation">
                            <xsl:with-param name="chopString">
                                <xsl:call-template name="subfieldSelect">
                                    <xsl:with-param name="codes">a_t</xsl:with-param>
                                </xsl:call-template>
                            </xsl:with-param>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:choose>
                        <xsl:when test="$UseControlNumber = '1' and marc:subfield[@code='w']">
                            <a><xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=Control-number:<xsl:call-template name="extractControlNumber"><xsl:with-param name="subfieldW" select="marc:subfield[@code='w']"/></xsl:call-template></xsl:attribute>
                            <xsl:value-of select="translate($f773, '()', '')"/>
                            </a>
                        </xsl:when>
                        <xsl:when test="marc:subfield[@code='0']">
                            <a><xsl:attribute name="href">/cgi-bin/koha/opac-detail.pl?biblionumber=<xsl:value-of select="str:encode-uri(marc:subfield[@code='0'], true())"/></xsl:attribute>
                            <xsl:value-of select="$f773"/>
                            </a>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:variable name="host_query">
                                <xsl:text>ti,phr:(</xsl:text>
                                <xsl:call-template name="quote_search_term">
                                    <xsl:with-param name="term"><xsl:value-of select="marc:subfield[@code='t']"/></xsl:with-param>
                                </xsl:call-template>
                                <xsl:text>)</xsl:text>
                                <xsl:if test="marc:subfield[@code='a']">
                                    <xsl:text> AND name:(</xsl:text>
                                    <xsl:call-template name="quote_search_term">
                                        <xsl:with-param name="term">
                                            <xsl:value-of select="marc:subfield[@code='a']"/>
                                        </xsl:with-param>
                                    </xsl:call-template>
                                    <xsl:text>)</xsl:text>
                                </xsl:if>
                            </xsl:variable>
                            <a>
                            <xsl:attribute name="href">/cgi-bin/koha/opac-search.pl?q=<xsl:value-of select="str:encode-uri($host_query, true())" />
                            </xsl:attribute>
                                <xsl:value-of select="$f773"/>
                            </a>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="marc:subfield[@code='g']">
                        <xsl:text> </xsl:text><xsl:value-of select="marc:subfield[@code='g']"/>
                    </xsl:if>
                    </span>
                    <xsl:if test="marc:subfield[@code='n']">
                        <span class="results_summary in_note"><xsl:value-of select="marc:subfield[@code='n']"/></span>
                    </xsl:if>
                </xsl:if>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>

    <xsl:template name="AddMissingProtocol">
        <xsl:param name="resourceLocation"/>
        <xsl:param name="indicator1"/>
        <xsl:param name="accessMethod"/>
        <xsl:param name="delimiter" select="':'"/>
        <xsl:if test="not(contains($resourceLocation, $delimiter))">
            <xsl:choose>
                <xsl:when test="$indicator1=7 and ( $accessMethod='mailto' or $accessMethod='tel' )">
                    <xsl:value-of select="$accessMethod"/><xsl:text>:</xsl:text>
                </xsl:when>
                <xsl:when test="$indicator1=7">
                    <xsl:value-of select="$accessMethod"/><xsl:text>://</xsl:text>
                </xsl:when>
                <xsl:when test="$indicator1=0">
                    <xsl:text>mailto:</xsl:text>
                </xsl:when>
                <xsl:when test="$indicator1=1">
                    <xsl:text>ftp://</xsl:text>
                </xsl:when>
                <xsl:when test="$indicator1=2">
                    <xsl:text>telnet://</xsl:text>
                </xsl:when>
                <xsl:when test="$indicator1=3">
                    <xsl:text>tel:</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>http://</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>

<!-- Stylus Studio meta-information - (c)1998-2002 eXcelon Corp.
<metaInformation>
<scenarios/><MapperInfo srcSchemaPath="" srcSchemaRoot="" srcSchemaPathIsRelative="yes" srcSchemaInterpretAsXML="no" destSchemaPath="" destSchemaRoot="" destSchemaPathIsRelative="yes" destSchemaInterpretAsXML="no"/>
</metaInformation>
-->
