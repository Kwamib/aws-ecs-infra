// ==========================================
// Jenkins Pipeline: ECS AMI Build & Terraform Deployment
// ==========================================

pipeline {
    agent any

    parameters {
        string(name: 'ENGINEER_NAME', defaultValue: '', description: 'Engineer responsible for this build')
    }

    environment {
        PATH    = "${PATH}:${getTerraformPath()}"
        AMI_ID  = "ecs-ami-${BUILD_NUMBER}"
        VERSION = "1.0.${BUILD_NUMBER}"
    }

    stages {

        // Manual approval to start
        stage('Initial Stage') {
            steps {
                script {
                    echo "Build initiated by: ${params.ENGINEER_NAME}"
                    input(
                        id: 'confirm',
                        message: 'Start Pipeline?',
                        parameters: [
                            [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Start Pipeline', name: 'confirm']
                        ]
                    )
                }
            }
        }

        // Packer AMI Build
        stage('Packer AMI Build') {
            steps {
                slackSend(color: '#FFFF00', message: "STARTING PACKER IMAGE BUILD by *${params.ENGINEER_NAME}*: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
                sh '''
                    sed -i "s/ecs-ami-'[0-9]*$'/'${AMI_ID}'/" images/image.pkr.hcl
                    export PACKER_LOG=1
                    export PACKER_LOG_PATH=$WORKSPACE/packer.log
                    /usr/bin/packer build -force images/image.pkr.hcl
                '''
            }
        }

        // Register AMI to SSM Parameter Store
        stage('Register AMI to SSM') {
            steps {
                script {
                    try {
                        def manifest = readJSON file: 'images/manifest.json'
                        def amiId = manifest.builds[0].artifact_id.tokenize(':')[-1]
                        def version = env.VERSION
                        def timestamp = new Date().format("yyyyMMddHHmmss")

                        env.BUILT_AMI_ID = amiId
                        env.AMI_VERSION = version

                        echo "Built AMI: ${amiId} (v${version})"

                        sh """
                            set -e
                            aws ssm put-parameter --name "/clixx/ecs-ami/v${version}" --value "${amiId}" --type "String" --description "ECS AMI v${version} built on ${timestamp}" --region us-east-1 --overwrite
                            aws ssm put-parameter --name "/clixx/ecs-ami/latest" --value "${amiId}" --type "String" --description "Latest ECS AMI - v${version}" --region us-east-1 --overwrite
                            aws ssm put-parameter --name "/clixx/ecs-ami/latest/version" --value "${version}" --type "String" --description "Version of latest ECS AMI" --region us-east-1 --overwrite
                            aws ssm put-parameter --name "/clixx/ecs-ami/latest/build-date" --value "${timestamp}" --type "String" --description "Build date of latest ECS AMI" --region us-east-1 --overwrite
                        """

                        slackSend(
                            color: 'good',
                            message: "*AMI BUILD & REGISTRATION SUCCESSFUL* by *${params.ENGINEER_NAME}*\nAMI ID: `${amiId}`\nVersion: `${version}`\nBuild: #${env.BUILD_NUMBER}"
                        )

                    } catch (Exception e) {
                        slackSend(color: 'danger', message: "*AMI REGISTRATION FAILED*\nError: ${e.getMessage()}")
                        throw e
                    }
                }
            }
        }

        // Terraform Init
        stage('Terraform Init') {
            steps {
                slackSend(color: '#FFFF00', message: "STARTING TERRAFORM DEPLOYMENT by *${params.ENGINEER_NAME}*")
                sh 'terraform init -upgrade'
            }
        }

        // Terraform State Cleanup (legacy resources)
        stage('Terraform State Cleanup') {
            steps {
                sh '''
                    terraform state rm aws_inspector_resource_group.stack_res || true
                    terraform state rm aws_inspector_assessment_target.assessment || true
                    terraform state rm aws_inspector_assessment_template.stack_hardening_rules || true
                '''
            }
        }

        // Terraform Plan
        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan -input=false'
            }
        }

        // Terraform Apply + Inspector Scan
        stage('Build Infrastructure & Vulnerability Scan') {
            steps {
                slackSend(color: '#FFFF00', message: "APPLYING INFRASTRUCTURE by *${params.ENGINEER_NAME}*")
                sh 'terraform apply -auto-approve'
            }
        }

        // Inspector Findings Report
        stage('Vulnerability Report') {
            steps {
                sh '''
                    echo "Inspector v2 is enabled and continuously scanning EC2 instances"
                    aws inspector2 list-findings --region us-east-1 --output json > inspector-findings.json || echo "No findings yet"

                    if [ -f inspector-findings.json ]; then
                        echo "Inspector findings saved"
                        cat inspector-findings.json
                    fi
                '''
                archiveArtifacts artifacts: 'inspector-findings.json', allowEmptyArchive: true
                slackSend(color: '#FFFF00', message: "DEPLOYMENT COMPLETED by *${params.ENGINEER_NAME}*")
            }
        }
    }

    post {
        success {
            slackSend(color: '#2ecc71', message: "BUILD SUCCESSFUL by *${params.ENGINEER_NAME}*: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
        }
        failure {
            slackSend(color: '#e74c3c', message: "BUILD FAILED by *${params.ENGINEER_NAME}*: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'")
        }
        unstable {
            slackSend(color: '#f39c12', message: "BUILD UNSTABLE by *${params.ENGINEER_NAME}*")
        }
        aborted {
            slackSend(color: '#95a5a6', message: "BUILD ABORTED by *${params.ENGINEER_NAME}*")
        }
        always {
            sh 'rm -f tfplan'
        }
    }
}

def getTerraformPath() {
    def tfHome = tool name: 'terraform-14', type: 'terraform'
    return tfHome
}
