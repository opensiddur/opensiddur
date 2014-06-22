<!-- 
    Convert 1917 JPS XML to JLPTEI

    Copyright 2014 Efraim Feinstein, efraim@opensiddur.org
    Open Siddur Project
    Licensed under the GNU Lesser General Public License, version 3 or later
-->
<xsl:stylesheet 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
    xmlns:local="local"
    version="2.0"
    exclude-result-prefixes="#all">
    <xsl:import href="../rawtext/split-word.xsl2"/>
    <xsl:import href="../fill-template.xsl2"/>
    <!-- 1917 JPS has front matter (title page + preface), followed by sections (The Law, The Prophets, Writings), 
    which contain books.  
    1917 JPS also divides by chapter/verse and parasha.
    Interestingly, we can use 1917 JPS to mark parshiot (and haftarot?), possibly as separate files
    -->

    <xsl:param name="input-directory" as="xs:string" select="'../../sources/1917JPS/books'"/>
    <xsl:param name="input-file" as="xs:string" select="concat($input-directory, '/index.html')"/>
    <xsl:param name="result-directory" as="xs:string" select="'../../build/data'"/>

    <xsl:variable name="bibliography-file" as="xs:string" select="concat('/data/sources/', encode-for-uri('The Holy Scriptures'))"/>
    
    <xsl:variable name="front-matter" as="xs:string+"
        select="(
            'TITLE PAGE', 
            'PREFACE', 
            'TABLE OF READINGS', 
            'THE ORDER OF THE BOOKS', 
            'THE LAW', 
            'THE PROPHETS', 
            'THE WRITINGS')"
        />


    <xsl:variable name="all-books" as="xs:string+" select="(
        'GENESIS',
        'EXODUS',
        'LEVITICUS',
        'NUMBERS',
        'DEUTERONOMY',
        'JOSHUA',
        'JUDGES',
        'FIRST SAMUEL',
        'SECOND SAMUEL',
        'FIRST KINGS',
        'SECOND KINGS',
        'ISAIAH',
        'JEREMIAH',
        'EZEKIEL',
        'PSALMS',
        'PROVERBS',
        'JOB',
        'SONG OF SONGS',
        'RUTH',
        'LAMENTATIONS',
        'ECCLESIASTES',
        'ESTHER',
        'DANIEL',
        'EZRA',
        'NEHEMIAH',
        'FIRST CHRONICLES',
        'SECOND CHRONICLES'
        )"/>

    <xsl:function name="local:chapter-filename" as="xs:string">
        <xsl:param name="book" as="xs:string"/>
        <xsl:param name="chapter" as="xs:integer"/>

        <xsl:sequence select="encode-for-uri(concat($book, ' ', $chapter))"/>
    </xsl:function>

    <xsl:variable name="bibliography-link" as="element(tei:link)">
        <tei:link type="bibl" target="#text {$bibliography-file}"/>
    </xsl:variable>

    <xsl:variable name="license" as="element(tei:licence)">
        <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
    </xsl:variable>

    <!-- book:
        for each book, create a book file that just links to each chapter
        if parshiot exist, create a parasha file that links to the Tanach
        for each chapter, create a JLPTEI file 
        *and* a linkage file to the Hebrew Tanach
    -->
    <xsl:template match="book|subsection">
        <xsl:for-each-group select="*" group-starting-with="book-title">
            <xsl:if test="current-group()/self::book-title">
                <xsl:variable name="book-name" 
                    select="
                    string-join(
                        for $token in tokenize(current-group()/self::book-title, ' ')
                        return concat(upper-case(substring($token, 1, 1)), lower-case(substring($token, 2)))
                    , ' ')"/>
                <xsl:result-document href="{$result-directory}/original/en/{$book-name}.xml">
                    <xsl:call-template name="fill-template">
                        <xsl:with-param name="xmllang" select="'en'"/>
                        <xsl:with-param name="title" as="element(tei:title)+">
                            <tei:title type="main" xml:lang="en"><xsl:value-of select="$book-name"/></tei:title>
                        </xsl:with-param>
                        <xsl:with-param name="license" as="element(tei:licence)" select="$license"/>
                        <xsl:with-param name="bibliography" as="element(tei:link)+" select="$bibliography-link"/>
                        <xsl:with-param name="body" as="element()+">
                            <j:streamText>
                                <xsl:attribute name="xml:id">text</xsl:attribute>
                                <xsl:for-each select="chapter-number">
                                    <tei:ptr target="/data/original/{local:chapter-filename($book-name, xs:integer(.))}#text">
                                        <xsl:attribute name="xml:id" select="concat('se_',number(.))"/>
                                    </tei:ptr>
                                </xsl:for-each>
                            </j:streamText>
                            <j:concurrent>
                                <j:layer type="div">
                                    <xsl:attribute name="xml:id" select="'main'"/>
                                    <tei:head><xsl:value-of select="$book-name"/></tei:head>
                                    <tei:ab>
                                        <tei:ptr target="#range(se_{min(chapter-number/number())},se_{max(chapter-number/number())})"/>
                                    </tei:ab>
                                </j:layer>
                            </j:concurrent>
                        </xsl:with-param>
                    </xsl:call-template>
                </xsl:result-document>

                <!-- chapters -->
                <xsl:for-each-group select="*" group-starting-with="chapter-number">
                    <xsl:variable name="chapter-number" select="current-group()/self::chapter-number" as="xs:string?"/>
                    <xsl:if test="$chapter-number">
                        <xsl:result-document href="{$result-directory}/original/en/{$book-name}{format-number(number($chapter-number), '000')}.xml">
                            <xsl:call-template name="fill-template">
                                <xsl:with-param name="xmllang" select="'en'"/>
                                <xsl:with-param name="title" as="element(tei:title)+">
                                    <tei:title type="main" xml:lang="en"><xsl:value-of select="concat($book-name, ' ', $chapter-number)"/></tei:title>
                                </xsl:with-param>
                                <xsl:with-param name="license" as="element(tei:licence)" select="$license"/>
                                <xsl:with-param name="bibliography" as="element(tei:link)" select="$bibliography-link"/>
                                <xsl:with-param name="body" as="element()+">
                                    <j:streamText>
                                        <xsl:attribute name="xml:id" select="'text'"/>
                                    </j:streamText>
                                    <j:concurrent>
                                        <xsl:attribute name="xml:id" select="'concurrent'"/>
                                    </j:concurrent>
                                </xsl:with-param>
                            </xsl:call-template>
                        </xsl:result-document>
                    </xsl:if>
                </xsl:for-each-group>
            </xsl:if>
        </xsl:for-each-group>
    </xsl:template>

    <!-- this is the main template that should run at start -->
    <xsl:template name="main">
        <xsl:apply-templates select="for $book in $all-books return doc(concat($input-directory, '/', $book, '.xml'))"/>
    </xsl:template>
</xsl:stylesheet>
