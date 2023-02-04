pipeline { 

    agent any 

    stages { 

        stage('Clone repository') { 

            steps { 

                git branch: 'main', 

                url: 'https://github.com/Ahmed-Nasr-hassan/terraform-project-2/' 

            } 

        } 

        stage('List contents') { 

            steps { 

                sh 'ls -la' 

            } 

        } 

    } 

} 
