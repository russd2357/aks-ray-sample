resource "random_id" "suffix" {
  byte_length = 6
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_prefix}-${random_id.suffix.id}"
  location = var.location

  tags = {
    owner = var.resource_group_owner
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azapi_resource" "aks_auto" {
  type      = "Microsoft.ContainerService/managedClusters@2024-06-02-preview"
  name      = "aks-${var.project_prefix}-${random_id.suffix.id}"
  parent_id = azurerm_resource_group.rg.id
  location  = var.location
  tags     = azurerm_resource_group.rg.tags
  
  body = jsonencode({

    properties = {
      kubernetesVersion = "1.31"
      nodeResourceGroup = "MC-aks-${var.project_prefix}-${random_id.suffix.id}"
      agentPoolProfiles = [
        {
          name    = "systempool"
          count   = var.system_node_pool_node_count
          vmSize  = var.system_node_pool_vm_size
          tags    = { owner = var.resource_group_owner }
          mode    = "System"
          osType  = "Linux"
          osSKU = "AzureLinux"
          osDiskSizeGB = 64
          enableAutoScaling = false
        }
      ]
      linuxProfile = {
        adminUsername = var.username
        ssh = {
          publicKeys = [
            {
              keyData = tls_private_key.ssh_key.public_key_openssh
            }
          ]
        }
      }

      azureMonitorProfile = {
        metrics = {
          enabled = true
          kubeStateMetrics = {
            metricAnnotationsAllowList = var.ksm_allowed_annotations
            metricLabelsAllowlist = var.ksm_allowed_labels
          }
        }
      }
    }

    identity = {
      type = "SystemAssigned"
    }

    sku = {
      name     = "Automatic"
      tier    = "Standard"
    }
  })
}

resource "azurerm_monitor_workspace" "amw" {
  name                = "amon-${var.project_prefix}-${random_id.suffix.id}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_monitor_data_collection_endpoint" "prom_endpoint" {
  name                = "prom-${var.project_prefix}-${random_id.suffix.id}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "Linux"
}

resource "azurerm_monitor_data_collection_rule" "azprom_dcr" {
  name                        = "promdcr-${var.project_prefix}-${random_id.suffix.id}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prom_endpoint.id

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.amw.id
      name               = azurerm_monitor_workspace.amw.name
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = [azurerm_monitor_workspace.amw.name]
  }
}

# associate to a Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "example_dcr_to_aks" {
  name                    = "dcr-${azapi_resource.aks_auto.name}"
  target_resource_id      = azapi_resource.aks_auto.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.azprom_dcr.id
}

# associate to a Data Collection Endpoint
resource "azurerm_monitor_data_collection_rule_association" "example_dce_to_aks" {
  target_resource_id          = azapi_resource.aks_auto.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prom_endpoint.id
}



data "azurerm_client_config" "current" {}