agent any
environment {
    AWS_REGION = 'il-central-1'
    ECR_REPOSITORY_URI = '314525640319.dkr.ecr.il-central-1.amazonaws.com/levi/nginx'
    IMAGE_TAG = "build-${BUILD_NUMBER}"
    FULL_IMAGE_NAME = "${ECR_REPOSITORY_URI}:${IMAGE_TAG}"
}

stages {
    stage('Build Docker Image') {
        steps {
            script {
                echo "Building Docker image: ${FULL_IMAGE_NAME}"
                sh "docker build -t ${FULL_IMAGE_NAME} ."
            }
        }
    }

  
    stages {
        // ... (Build Docker Image stage)

        // Stage 2: Push Docker Image to ECR
        stage('Push to ECR') {
            steps {
                // Use the withCredentials block to access the stored AWS credentials
                // Replace 'aws-ecr-terraform' with the ID you gave your credentials in Jenkins
                withCredentials([aws(credentialsId: 'aws-ecr-terraform)', variablePrefix: 'AWS')]) {
                    script {
                        // Authenticate Docker with ECR using the credentials exposed as environment variables
                        // The 'variablePrefix: 'AWS'' makes the credentials available as AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
                        echo "Authenticating with ECR in region: ${AWS_REGION}"
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"

                        // Push the built image to the ECR repository
                        echo "Pushing Docker image to ECR: ${FULL_IMAGE_NAME}"
                        sh "docker push ${FULL_IMAGE_NAME}"

                        // Optional: Remove the local image after pushing to save space
                        // echo "Removing local Docker image: ${FULL_IMAGE_NAME}"
                        // sh "docker rmi ${FULL_IMAGE_NAME}"
                    }
                }
            }
        }

        // Stage 3: Deploy with Terraform
        stage('Deploy with Terraform') {
             steps {
                 
                // You would also wrap the terraform steps in a withCredentials block
                withCredentials([aws(credentialsId: 'aws-ecr-terraform)', variablePrefix: 'AWS')]) {
                    script {
                        // Navigate to the directory containing your Terraform code
                        dir('terraform') {
                            // Initialize Terraform (downloads providers, modules, etc.)
                            echo "Initializing Terraform"
                            sh "terraform init"

                            // Plan the Terraform deployment
                            echo "Planning Terraform deployment"
                            // Terraform will automatically pick up the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
                            sh "terraform plan -out=tfplan -var=\"image_name=${FULL_IMAGE_NAME}\""

                            // Apply the Terraform plan
                            echo "Applying Terraform deployment"
                            sh "terraform apply -auto-approve tfplan"
                        }
                    }
                }
            }
        }
    }


