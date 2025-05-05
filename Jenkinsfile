// Define the agent where the pipeline will run
agent any

// Define environment variables
environment {
    // Replace with your AWS region
    AWS_REGION = 'il-central-1'
    // Replace with your ECR repository URI
    ECR_REPOSITORY_URI = '314525640319.dkr.ecr.il-central-1.amazonaws.com/levi/nginx'
    // Define the image tag (using the build number is a good practice)
    IMAGE_TAG = "build-${BUILD_NUMBER}"
    // Define the full image name
    FULL_IMAGE_NAME = "${ECR_REPOSITORY_URI}:${IMAGE_TAG}"
}

// Define the stages of the pipeline
stages {
    // Stage 1: Build the Docker Image
    stage('Build Docker Image') {
        steps {
            script {
                // Build the Docker image using the Dockerfile in the current directory
                // Tag the image with the full ECR repository URI and the build number
                echo "Building Docker image: ${FULL_IMAGE_NAME}"
                sh "docker build -t ${FULL_IMAGE_NAME} ."
            }
        }
    }

    // Stage 2: Push Docker Image to ECR
    stage('Push to ECR') {
        steps {
            // Use the withCredentials block to access the stored AWS credentials
            // Replace 'aws-ecr-terraform' with the ID you gave your credentials in Jenkins
            // FIX: Corrected the syntax of credentialsId
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
            // FIX: Corrected the syntax of credentialsId
            withCredentials([aws(credentialsId: 'aws-ecr-terraform)', variablePrefix: 'AWS')]) {
                script {
                    // Navigate to the directory containing your Terraform code
                    // Replace 'terraform' with the actual path to your Terraform files if they are in a subdirectory
                    dir('terraform') {
                        // Initialize Terraform (downloads providers, modules, etc.)
                        echo "Initializing Terraform"
                        sh "terraform init"

                        // Plan the Terraform deployment
                        // Output the plan to a file (optional but recommended for review)
                        echo "Planning Terraform deployment"
                        // Terraform will automatically pick up the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
                        sh "terraform plan -out=tfplan -var=\"image_name=${FULL_IMAGE_NAME}\""

                        // Apply the Terraform plan
                        // The '-auto-approve' flag automatically applies the plan without manual confirmation
                        // In a production environment, you might remove '-auto-approve' and add a manual approval step in Jenkins
                        echo "Applying Terraform deployment"
                        sh "terraform apply -auto-approve tfplan"
                    }
                }
            }
        }
    }
}

// Optional: Post-build actions (e.g., clean up workspace)
// post {
//     always {
//         echo 'Cleaning up workspace...'
//         cleanWs()
//     }
// }
