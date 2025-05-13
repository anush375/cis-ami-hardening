packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_name" {
  default = "hardened-image-{{timestamp}}"
}

source "amazon-ebs" "ami" {
  region           = "us-east-1"
  source_ami       = "ami-0e2c8caa4b6378d8c" 
  instance_type    = "t2.medium"
  ssh_username     = "ubuntu"
  ami_name         = var.ami_name
  iam_instance_profile = "example-instance-profile-jenkins"

tags = {
  "Environment" = "Dev"  # Dynamic value using timestamp()
  "Project"     = "project-10"  # Dynamic value using timestamp()
  
  }
}
build {
  sources = ["source.amazon-ebs.ami"]

  provisioner "shell" {
    inline = [
      "echo 'Installing dependencies...'",
      "sudo apt-get update -y",
      "sudo apt-get install -y curl build-essential nginx unzip jq git",  
      
      "echo 'Downloading AWS CLI installer...'",
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      "echo 'Verifying AWS CLI installation...'",
      "aws --version",
      
      # Fetch the Bitbucket password and store it in a variable
      "aws secretsmanager get-secret-value --secret-id 'password-bbucket' --query 'SecretString' --output text | jq -r '.\"Bitbucket app password\"' > /tmp/bb_password",
      
      # Clone the repository using the stored password
      "sudo git clone https://ssalimov1:$(cat /tmp/bb_password)@bitbucket.org/akumoproject10/app-dev-techfleets-stack.git /tms-app",
      
      # Install Node.js (LTS version)
      "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",
      "sudo apt install -y nodejs",
      # Verify installation
      "node -v",
      "npm -v",
      
      # Install PM2 globally
      "sudo npm install -g pm2",
      # Verify installation
      "pm2 --version",
      
      # Navigate to the cloned project directory
      "cd /tms-app",
      
      # Install dependencies
      
      # Setup environment by executing .setupENV.py
      
      "sudo python3 .setENV.py",
      
      # Build the application
      "sudo npm install --global yarn",
      "sudo yarn build",
      
      # Start the app using PM2
      "sudo pm2 start yarn --name 'tms-app' -- start",
      
      # Auto-start PM2 on system reboot
      "sudo pm2 save",
      "sudo pm2 startup",
      
      # Create Nginx configuration file using heredoc properly
      "echo 'server {' | sudo tee /etc/nginx/sites-available/tms-app",
      "echo '    listen 80;' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '    server_name your-domain.com;' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '    location / {' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '        proxy_pass http://localhost:3000;' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '        proxy_http_version 1.1;' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '        proxy_set_header Upgrade $http_upgrade;' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '        proxy_set_header Connection \"upgrade\";' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '        proxy_set_header Host $host;' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '        proxy_cache_bypass $http_upgrade;' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '    }' | sudo tee -a /etc/nginx/sites-available/tms-app",
      "echo '}' | sudo tee -a /etc/nginx/sites-available/tms-app",

      
      # Enable the Nginx configuration
      "sudo ln -sf /etc/nginx/sites-available/tms-app /etc/nginx/sites-enabled/",
      
      # Restart Nginx
      "sudo systemctl restart nginx"
    ]
  }
}

