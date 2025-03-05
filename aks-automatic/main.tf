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
  type      = "Microsoft.ContainerService/managedClusters@2024-10-02-preview"
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
            metricsAnnotationsAllowList = var.ksm_allowed_annotations
            metricsLabelsAllowList = var.ksm_allowed_labels
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




data "azurerm_client_config" "current" {}

