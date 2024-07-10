locals {

  tags = merge(
    {
    "Environment" = var.env
    "Terraformed" = "true"
    "Owner" = var.owner
    "Project" = var.project
    "IO Code" = var.iocode
    "ACN" = var.acn
    "LEAP" = var.leap_name   
    },

       var.additional_tags     
  )
}

provider "azurerm" {
    
    features {}
 
}

# Generate a random integer to create a globally unique name
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

data "azurerm_resource_group" "wbg_resource_group" {
  name                = var.given_resource_group_name
    
}

data "azurerm_resource_group" "wbg_asp_resource_group" {
  name                = var.given_asp_resource_group_name
  
   }

resource "azurerm_user_assigned_identity" "identity" {
  count               = var.managed_identity == true ? 1 : 0
  resource_group_name = data.azurerm_resource_group.wbg_resource_group.name
  location            = data.azurerm_resource_group.wbg_resource_group.location
  tags = local.tags

  lifecycle {
    ignore_changes = ["tags"]
}
   
  name =  (
    var.managed_identity_name != "" ? var.managed_identity_name :
    "MI-${lower(var.lob)}-${lower(var.project)}-aas-${lower(var.env)}-${random_integer.ri.result}"
  )
}

data "azurerm_service_plan" "wbg_service_plan" {
  resource_group_name = data.azurerm_resource_group.wbg_asp_resource_group.name
  name                = var.given_service_plan_name
 
}
# ==================== Windows App ======================== #
resource "azurerm_windows_web_app" "wbg_windows_webapp" {
  count = (
      data.azurerm_service_plan.wbg_service_plan.kind == "Windows" ||
      data.azurerm_service_plan.wbg_service_plan.kind == "app" ? 1 : 0
  )

  lifecycle {
  ignore_changes = ["tags"]
}

  name = (
    var.overrite_name ? var.webapp_name :
    "${lower(var.lob)}-${lower(var.project)}-${lower(var.env)}-${random_integer.ri.result}"
    )
  location            = data.azurerm_resource_group.wbg_resource_group.location
  resource_group_name = data.azurerm_resource_group.wbg_resource_group.name
  service_plan_id     = data.azurerm_service_plan.wbg_service_plan.id

  dynamic "identity" {
    for_each = var.managed_identity ? [1] : []
    content {
        type         = "UserAssigned"
        identity_ids = [azurerm_user_assigned_identity.identity[0].id]
    }
  }

  dynamic "auth_settings" {
    for_each = var.auth_enabled ? [1] : []
    content {
      enabled = true 
      active_directory  {
        client_id         = var.client_id
        client_secret     = var.client_secret
        allowed_audiences = var.allowed_origins
      }
      default_provider = "AzureActiveDirectory"
      issuer = var.issuer_url
    }
  }

  site_config {
    http2_enabled = true
    websockets_enabled  = var.websockets_enabled
    use_32_bit_worker = false
    application_stack {
      current_stack   = var.app_stack
      java_version    = var.app_stack == "java" ?   var.java_version : null
      dotnet_version  = var.app_stack == "dotnet" || var.app_stack == "dotnetcore" ? var.dotnet_version : null
      node_version    = var.app_stack == "node" ? var.node_version : null
      php_version     = var.app_stack == "php" ?    var.php_version : null
      python_version  = var.app_stack == "python" ? var.python_version : null

    }
  }
  key_vault_reference_identity_id = var.managed_identity ? azurerm_user_assigned_identity.identity[0].id : null
  https_only  = true
  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
  tags = local.tags

}
# ======================= Linux App ============================= #
resource "azurerm_linux_web_app" "wbg_linux_webapp" {
  count = (
    data.azurerm_service_plan.wbg_service_plan.kind == "linux" ? 1 : 0
    )

  lifecycle {
  ignore_changes = ["tags"]
}
  name = (
    var.overrite_name ? var.webapp_name :
    "${lower(var.lob)}-${lower(var.project)}-${lower(var.env)}-${random_integer.ri.result}"
    )

  location            = data.azurerm_resource_group.wbg_resource_group.location
  resource_group_name = data.azurerm_resource_group.wbg_resource_group.name
  service_plan_id     = data.azurerm_service_plan.wbg_service_plan.id

  dynamic "identity" {
    for_each = var.managed_identity ? [1] : []
    content {
        type         = "UserAssigned"
        identity_ids = [azurerm_user_assigned_identity.identity[0].id]
    }
  }
  
  dynamic "auth_settings" {
    for_each = var.auth_enabled ? [1] : []
    content {
      enabled = true 
      active_directory  {
        client_id         = var.client_id
        client_secret     = var.client_secret
        allowed_audiences = var.allowed_origins
      }
      default_provider = "AzureActiveDirectory"
      issuer = var.issuer_url
    }
  }

  site_config {
    http2_enabled = true
    websockets_enabled  = var.websockets_enabled
    use_32_bit_worker = false
    application_stack {
      java_version        = var.app_stack == "java" ?   var.java_version : null
      java_server         = var.app_stack == "java" ?   var.java_server : null
      java_server_version = var.app_stack == "java" ?   var.java_server_version : null      
      dotnet_version      = var.app_stack == "dotnet" ? var.dotnet_version : null
      node_version        = var.app_stack == "node" ? var.node_version : null
      php_version         = var.app_stack == "php" ?    var.php_version : null
      python_version      = var.app_stack == "python" ? var.python_version : null
      ruby_version        = var.app_stack == "ruby" ?   var.ruby_version : null
    }
  }

  key_vault_reference_identity_id = var.managed_identity ? azurerm_user_assigned_identity.identity[0].id : null
  https_only  = true
  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
  tags = local.tags
  
