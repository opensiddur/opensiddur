<?xml version="1.0" encoding="utf-8"?>
<!-- Make changes to conf.xml required for setup. Input is the existing conf.xml -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
  <xsl:output method="xml" indent="yes"/>
  
  <!-- default operation is identity -->
  <xsl:template match="element()|comment()">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
  
  <!-- add the scheduled tasks -->
  <xsl:template match="scheduler">
    <!-- cron-trigger:
      S M H D M W [Y]
      S = seconds, M = minute, H = hour, D = day, M = month, W = day of week (1-7) Y = year
     -->
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
      <!-- background scheduler task, runs every second -->
      <job type="user" 
            xquery="/db/apps/opensiddur-server/modules/bg.xql" 
            period="1000" delay="5000" 
            unschedule-on-exception="no"/>  

      <!-- backup to file system task to run at 12am every day -->
      <job type="system" name="check1" 
        class="org.exist.storage.ConsistencyCheckTask"
        cron-trigger="0 0 0 * * ?">
          <parameter name="output" value="export"/>
          <parameter name="backup" value="yes"/>
          <parameter name="incremental" value="no"/>
          <parameter name="incremental-check" value="no"/>
          <parameter name="max" value="2"/>
          <parameter name="zip" value="no"/>
      </job>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>  
