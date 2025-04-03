output aks_cluster_name {
  value = azapi_resource.aks_auto.name
}

output resource_group_name {
  value = azurerm_resource_group.rg.name
}

output azure_monitor_workspace_name {
  value = azurerm_monitor_workspace.amw.name
}

output grafana_dashboard_name {
  value = azurerm_dashboard_grafana.graf.name
}

output data_collection_rule_id {
  value = azurerm_monitor_data_collection_rule.azprom_dcr.immutable_id
}

output data_collection_endpoint_url {
  value = azurerm_monitor_data_collection_endpoint.prom_endpoint.logs_ingestion_endpoint
}
