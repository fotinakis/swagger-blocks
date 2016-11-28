require 'swagger/blocks/root'
require 'swagger/blocks/internal_helpers'
require 'swagger/blocks/class_methods'

module Swagger
  module Blocks
    autoload :Node, 'swagger/blocks/node'

    module Errors
      autoload :Error, 'swagger/blocks/errors/error'
      autoload :DeclarationError, 'swagger/blocks/errors/declaration_error'
      autoload :NotFoundError, 'swagger/blocks/errors/not_found_error'
      autoload :NotSupportedError, 'swagger/blocks/errors/not_supported_error'
    end

    module Nodes
      autoload :AllOfNode, 'swagger/blocks/nodes/all_of_node'
      autoload :ApiAuthorizationNode, 'swagger/blocks/nodes/api_authorization_node'
      autoload :ApiAuthorizationScopeNode, 'swagger/blocks/nodes/api_authorization_scope_node'
      autoload :ApiAuthorizationsNode, 'swagger/blocks/nodes/api_authorizations_node'
      autoload :ApiDeclarationNode, 'swagger/blocks/nodes/api_declaration_node'
      autoload :ApiNode, 'swagger/blocks/nodes/api_node'
      autoload :AuthorizationCodeNode, 'swagger/blocks/nodes/authorization_code_node'
      autoload :ContactNode, 'swagger/blocks/nodes/contact_node'
      autoload :ExampleNode, 'swagger/blocks/nodes/example_node'
      autoload :ExternalDocsNode, 'swagger/blocks/nodes/external_docs_node'
      autoload :GrantTypesNode, 'swagger/blocks/nodes/grant_types_node'
      autoload :HeaderNode, 'swagger/blocks/nodes/header_node'
      autoload :ImplicitNode, 'swagger/blocks/nodes/implicit_node'
      autoload :InfoNode, 'swagger/blocks/nodes/info_node'
      autoload :ItemsNode, 'swagger/blocks/nodes/items_node'
      autoload :LicenseNode, 'swagger/blocks/nodes/license_node'
      autoload :LoginEndpointNode, 'swagger/blocks/nodes/login_endpoint_node'
      autoload :ModelNode, 'swagger/blocks/nodes/model_node'
      autoload :ModelsNode, 'swagger/blocks/nodes/models_node'
      autoload :OperationNode, 'swagger/blocks/nodes/operation_node'
      autoload :ParameterNode, 'swagger/blocks/nodes/parameter_node'
      autoload :PathNode, 'swagger/blocks/nodes/path_node'
      autoload :PropertiesNode, 'swagger/blocks/nodes/properties_node'
      autoload :PropertyNode, 'swagger/blocks/nodes/property_node'
      autoload :ResourceListingAuthorizationNode, 'swagger/blocks/nodes/resource_listing_authorization_node'
      autoload :ResourceListingAuthorizationsNode, 'swagger/blocks/nodes/resource_listing_authorizations_node'
      autoload :ResourceNode, 'swagger/blocks/nodes/resource_node'
      autoload :ResponseNode, 'swagger/blocks/nodes/response_node'
      autoload :RootNode, 'swagger/blocks/nodes/root_node'
      autoload :SchemaNode, 'swagger/blocks/nodes/schema_node'
      autoload :ScopeNode, 'swagger/blocks/nodes/scope_node'
      autoload :ScopesNode, 'swagger/blocks/nodes/scopes_node'
      autoload :SecurityRequirementNode, 'swagger/blocks/nodes/security_requirement_node'
      autoload :SecuritySchemeNode, 'swagger/blocks/nodes/security_scheme_node'
      autoload :TagNode, 'swagger/blocks/nodes/tag_node'
      autoload :TokenEndpointNode, 'swagger/blocks/nodes/token_endpoint_node'
      autoload :TokenRequestEndpointNode, 'swagger/blocks/nodes/token_request_endpoint_node'
      autoload :XmlNode, 'swagger/blocks/nodes/xml_node'
    end
  end
end
