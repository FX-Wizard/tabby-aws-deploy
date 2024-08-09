# TabbyML on AWS with Opentofu

[Tabby](https://tabby.tabbyml.com/) is an awesome bit of open source kit for programmers wanting an AI programming assistant they can run on their own hardware.

## Prerequisites
- [Open Tofu](https://opentofu.org/docs/intro/install/) installed on your machine
- Access to an AWS account with appropriate permissions


## What this deploys

- Tabby container running on ECS
- Nvidia GPU enabled ECS cluster
- EFS for persistant storage of config and AI models

## Getting started

### 1. Configure Open Tofu

1. Clone this repository to your local machine.
2. Navigate to the project directory.
3. Create a `terraform.tfvars` file and configure the required variables (e.g., AWS region, instance types, etc.).

### 2. Public or private access

If you just want to use Tabby inside your VPC then you can skip to the next step.

If you want to access Tabby over the internet you'll need to set the `is_public` var to true

You'll also need to provide a domain name and ACM certificate ARN for the loadbalancer to use SSL

### Setting AI models

You can find all the models supported out of the box by Tabby here: https://tabby.tabbyml.com/docs/models/

Tabby needs 2 models, one for code completion and another for chat. You can choose these by setting the `tabby_model` and `tabby_chat_model` variables with your model of choice. 

Just be aware bigger models need a bigger EC2 instance to run on so you'll also need to set `gpu_instance_type` to an instance with a big enough GPU to run the models. I find a G5.2xlarge with its 24GB Nvidia A10 GPU big enough to fit 2 7b models.