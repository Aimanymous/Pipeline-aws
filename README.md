# Pipeline-aws

Prerequisites
Before you begin, ensure you have the following installed:

-Terraform
-Docker
-AWS account 
-AWS CLI


Cloud Deployment Steps:

1. Clone the Repository
Clone this repository to your local machine.

git clone https://github.com/Aimanymous/Pipeline-aws.git
cd <repository_directory>

2. Initialize Terraform
In the root directory of your project, run the following command to initialize the Terraform project:

terraform init

3. Plan the Deployment: Review the changes that Terraform will apply.

terraform plan

4. Apply Terraform Configuration
Run the following command to create the resources on AWS. Terraform will prompt you to confirm the action before proceeding.

terraform apply



local Deployment:

docker build -t (image_name):(tag) .

docker run -p 8080:800 (image_name):(tag)