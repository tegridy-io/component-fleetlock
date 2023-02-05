local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.fleetlock;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('fleetlock', params.namespace);

{
  fleetlock: app,
}
