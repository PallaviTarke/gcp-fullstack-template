# terraform/main.tf

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = "ha-vpc"
}

resource "google_compute_firewall" "allow_all" {
  name    = "allow-internal-external"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "3000", "27017", "27018", "6379", "6380", "9090", "9100", "3001"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "default" {
  account_id   = "ha-app-sa"
  display_name = "HA App Service Account"
}

resource "google_compute_instance_template" "app_template" {
  name           = "ha-app-template"
  machine_type   = "e2-medium"
  region         = var.region
  can_ip_forward = false

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = google_compute_network.vpc_network.id
    access_config {}
  }

  metadata_startup_script = file("${path.module}/startup.sh")

  service_account {
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server"]
}

resource "google_compute_instance_group_manager" "app_group" {
  name               = "ha-app-group"
  base_instance_name = "ha-app"
  version {
    instance_template = google_compute_instance_template.app_template.id
  }
  target_size = 2
  zone        = var.zone
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_health_check" "basic_check" {
  name               = "ha-health-check"
  check_interval_sec = 10
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "ha-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.basic_check.id]
  backend {
    group = google_compute_instance_group_manager.app_group.instance_group
  }
}

resource "google_compute_url_map" "http_map" {
  name            = "ha-url-map"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name   = "ha-http-proxy"
  url_map = google_compute_url_map.http_map.id
}

resource "google_compute_global_forwarding_rule" "http_lb" {
  name        = "ha-http-forwarding-rule"
  ip_protocol = "TCP"
  port_range  = "80"
  target      = google_compute_target_http_proxy.http_proxy.id
}
