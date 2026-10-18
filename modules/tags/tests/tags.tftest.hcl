variables {
  application = "example-app"
  environment = "lab"
  owner_email = "platform@example.com"
  account     = "example-account"
  source_path = "ExampleOrg/example-infra/live/lab"
}

run "produces_map_and_list_forms" {
  command = plan

  assert {
    condition = output.map == {
      application = "example-app"
      environment = "lab"
      owner_email = "platform@example.com"
      account     = "example-account"
      managed_by  = "opentofu"
      source      = "exampleorg/example-infra/live/lab"
    }
    error_message = "Map form must carry every shared key, lowercased."
  }

  assert {
    condition     = contains(output.list, "owner_email:platform@example.com")
    error_message = "List form must use key:value strings."
  }

  assert {
    condition     = alltrue([for t in output.list : length(t) <= 50])
    error_message = "Every key:value string must fit Akamai's 50-character tag limit."
  }

  assert {
    condition     = output.list == sort(output.list)
    error_message = "List form must be sorted so its order never changes between plans."
  }
}

run "rejects_uppercase_environment" {
  command = plan

  variables {
    environment = "Production"
  }

  expect_failures = [var.environment]
}

run "rejects_customer_tenant_vocabulary" {
  command = plan

  variables {
    environment = "dev"
  }

  expect_failures = [var.environment]
}

run "rejects_non_email_owner" {
  command = plan

  variables {
    owner_email = "platform team"
  }

  expect_failures = [var.owner_email]
}
