component {

    settings = {
        username : '',
        password : '',
        // http://jenkins.myserver.com:8080/
        jenkinsAPIURL : ''
    };

    function configure() {
		wirebox.getBinder()
			.map( [ "JenkinsRunner", "JenkinsRunner@jenkins-runner" ] )
			.to( "jenkins-runner.models.JenkinsRunner" )
			.initArg( name="username", value=settings.username )
			.initArg( name="password", value=settings.password )
			.initArg( name="jenkinsAPIURL", value=settings.jenkinsAPIURL );
    }

}