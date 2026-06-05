<?php
$config['use_https'] = true;
$_SERVER['SERVER_PORT'] = '443';

$config['oauth_provider'] = 'generic';
$config['oauth_provider_name'] = 'Pocket ID';
$config['oauth_client_id'] = '${OAUTH_CLIENT_ID}';
$config['oauth_client_secret'] = '${OAUTH_CLIENT_SECRET}';
$config['oauth_auth_uri'] = 'https://id.${ROOT_DOMAIN}/authorize';
$config['oauth_token_uri'] = 'https://id.${ROOT_DOMAIN}/api/oidc/token';
$config['oauth_identity_uri'] = 'https://id.${ROOT_DOMAIN}/api/oidc/userinfo';
$config['oauth_identity_fields'] = ['email'];
$config['oauth_scope'] = 'email openid profile';

$config['oauth_login_redirect'] = true;
?>
