component accessors=true singleton {
    property name='username';
    property name='password';
    property name='jenkinsAPIURL';

    function init( username, password, jenkinsAPIURL ) {
        if( !isNull( arguments.username ) ) {
            setUsername( arguments.username );
        }
        if( !isNull( arguments.password ) ) {
            setPassword( arguments.password );
        }
        if( !isNull( arguments.jenkinsAPIURL ) ) {
            setJenkinsAPIURL( arguments.jenkinsAPIURL );
        }
    }

    /**
     * Run a Jenkins's job via its API
     *
     * @jobName Name of the job in the format 'Scheduled%20Jobs/job/Daily/job/TestJob/'
     * @jobParameters A struct of name/value pairs if the job is parameterized
     * @returnOutput True will block until job is finished and returns text of console output
     * @jobOutputUDF UDF which will be called with every chunk of job output so you can flush it out to a console or browser.
     * @timeoutSeconds Number of seconds to timeout.  Exception will be thrown with console output thus far in extrainfo.
     */
    function run(
        string jobName,
        struct jobParameters={},
        boolean returnOutput=false,
        timeoutSeconds=60*5,
        jobOutputUDF
    ) {
        if( !isNull( arguments.jobOutputUDF ) ) {
            arguments.returnOutput=true;
        }

        var jobURL = getJenkinsAPIURL() & 'job/' & jobName;
        if( !jobURL.endsWith( '/' ) ) jobURL &= '/';

        // Find if this job has parameters
        var thisURL = jobURL & 'api/json';
        http url=thisURL result='local.cfhttp' throwOnError=false username=getUsername() password=getPassword() timeout=10;
        if( !isJSON( cfhttp.fileContent ) ) {
            throw( message="Error getting job info: #cfhttp.statuscode# - #thisURL#", detail=cfhttp.fileContent );
        }
        var jobInfo = deserializeJSON( cfhttp.fileContent );
        var hasParameters = !!jobInfo.property.find( (prop)=>prop._class contains 'ParametersDefinitionProperty' );

        // Get a CSRF token (and session cookie)
        var thisURL = getJenkinsAPIURL() & 'crumbIssuer/api/json';
        http url=thisURL result='local.cfhttp' throwOnError=false username=getUsername() password=getPassword() timeout=10;
        if( !isJSON( cfhttp.fileContent ) ) {
            throw( message="Error getting crumb info: #cfhttp.status_code# - #thisURL#", detail=cfhttp.fileContent );
        }
        var crumbInfo = deserializeJSON( cfhttp.fileContent );
        var cookies = cfhttp.cookies;

        // Actually fire the build (passing CSRF token and session cookie)
        var thisURL = jobURL & 'build#( hasParameters ? 'WithParameters' : '' )#';
        http url=thisURL result='local.cfhttp' method='POST' throwOnError=false username=getUsername() password=getPassword() timeout=10 {
            httpParam type='header' name=crumbInfo.crumbRequestField value=crumbInfo.crumb;
            jobParameters.each( (k,v)=>{ httpParam type='url' name=k value=v; } );
            cookies.each( (row)=>{ httpParam type='cookie' name=row.name value=row.value; } );

        }

        if( cfhttp.status_code != 201 ) {
            throw( message="Error starting job: #cfhttp.statuscode# - #thisURL#", detail=cfhttp.fileContent );
        }
        // If we dont want the job output, just abort here
        if( !returnOutput ) return '';

        var queueLocationURL = cfhttp.responseHeader.location;

        var getQueueInfo = ()=>{
            var thisURL = queueLocationURL & 'api/json';
            http url=thisURL result='local.cfhttp' throwOnError=false username=getUsername() password=getPassword() timeout=10;
            return deserializeJSON( cfhttp.fileContent );
        };

        var queueInfo={};
        var start = getTickCount();
        var timeoutAt = start + ( timeoutSeconds * 1000 );
        // Loop until the job has started running somewhere and we have a build number.
        do{
            sleep( 1000 )
            queueInfo = getQueueInfo();
        }
        while ( !queueInfo.keyExists( 'executable' ) && getTickCount() <= timeoutAt )

        if( !queueInfo.keyExists( 'executable' ) ) {
            throw( message="Gave up waiting for job to start for [#timeoutSeconds#] seconds." );
        }

        var buildID = queueInfo.executable.number;
        var buildURL = queueInfo.executable.url;
        var jobConsoleOutput = '';

        var getBuildInfo = ()=>{
            var thisURL = buildURL & 'api/json';
            http url=thisURL result='local.cfhttp' throwOnError=false username=getUsername() password=getPassword() encodeurl=false timeout=10;
            if( !isJSON( cfhttp.fileContent ) ) {
                throw( message="Error getting build info: #cfhttp.statuscode# - #thisURL#", detail=cfhttp.fileContent );
            }
            return deserializeJSON( cfhttp.fileContent );
        };

        var getJobOutput = ()=>{
            // Jenkins seems to have a bug where if your "start" position lands in the middle of the name of the user running the build, there is some sort of extra
            // metadata around that which gets cut in half and leaves junk in the output, throwing off the count.  The only way I can get this to work reliably is to
            // get all text and find out what changed.
            var thisURL = buildURL & 'consoleText/progressiveText?start=0';
            http url=thisURL result='local.cfhttp' throwOnError=false username=getUsername() encodeurl=false password=getPassword() timeout=10;
            if( len( jobConsoleOutput ) ) {
                var chunk = cfhttp.fileContent.replaceNoCase( jobConsoleOutput, '' );
            } else {
                var chunk = cfhttp.fileContent;
            }
            jobConsoleOutput = cfhttp.fileContent;
            return chunk;
        };

        var lastBuildInfo = {};
        // loop until the job finishes
        do{
            sleep( 500 )
            lastBuildInfo = getBuildInfo();
            if( !isNull( arguments.jobOutputUDF ) ) {
                var chunk = getJobOutput();
                if( len( chunk ) ) {
                    jobOutputUDF( chunk );
                }
            }
        }
        while ( lastBuildInfo.building && getTickCount() <= timeoutAt )

        if( isNull( arguments.jobOutputUDF ) ) {
            jobConsoleOutput = getJobOutput();
        }

        if( lastBuildInfo.building ) {
            throw( message="Gave up waiting for job to finish for [#timeoutSeconds#] seconds.", extendedInfo=jobConsoleOutput );
        }

        return jobConsoleOutput;
    }

}