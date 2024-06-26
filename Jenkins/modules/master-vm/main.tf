module "network" {
  source = "/root/Jenkins/modules/network"  # Adjust the path as needed
}

module "service-account" {
source = "/root/Jenkins/modules/service-account"
}

locals {
  env = "master"
}

resource "google_compute_instance" "my_instance" {
  name         = local.env
  machine_type = "n2-standard-2"
  zone         = "us-west1-b"

  boot_disk {
    auto_delete = true

    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240519"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = module.network.network_self_link
    subnetwork = module.network.subnetwork_master_self_link
    access_config {}
  }

  service_account {
    email  = module.service-account.svc_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["jenkins"]

  metadata_startup_script = <<-EOF
    #! /bin/bash
    sudo apt-get update
    sudo apt install git -y
    sudo apt install -y openjdk-17-jre wget vim

    # Install Jenkins
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install jenkins -y
    sudo systemctl start jenkins
    sudo systemctl enable jenkins

    # Install Maven
    wget https://apache.osuosl.org/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz
    tar xzvf apache-maven-3.9.5-bin.tar.gz
    sudo mv apache-maven-3.9.5 /opt
    echo 'export M2_HOME=/opt/apache-maven-3.9.5' >> ~/.bashrc
    echo 'export PATH=$M2_HOME/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc


    # Installing docker
    sudo apt install docker.io -y
    sudo sed -i '14s|.*|ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock|' /lib/systemd/system/docker.service
    sudo systemctl daemon-reload
    sudo systemctl restart docker
  EOF
}
