// main template for fleetlock
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.fleetlock;
local appName = 'fleetlock';

local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    labels+: {
      'app.kubernetes.io/name': params.namespace,
    },
  },
};


// RBAC

local serviceAccount = kube.ServiceAccount(appName) {
  metadata+: {
    namespace: params.namespace,
  },
};

local clusterRole = kube.ClusterRole(appName) {
  rules: [
    { apiGroups: [ '' ], resources: [ 'nodes' ], verbs: [ 'list', 'patch' ] },
    { apiGroups: [ '' ], resources: [ 'pods' ], verbs: [ 'list' ] },
    { apiGroups: [ '' ], resources: [ 'pods/eviction' ], verbs: [ 'create' ] },
  ],
};

local clusterRoleBinding = kube.ClusterRoleBinding(appName) {
  subjects_: [ serviceAccount ],
  roleRef_: clusterRole,
};

local role = kube.Role(appName) {
  metadata+: {
    namespace: params.namespace,
  },
  rules: [
    { apiGroups: [ 'coordination.k8s.io' ], resources: [ 'leases' ], verbs: [ 'create', 'get', 'update' ] },
  ],
};

local roleBinding = kube.RoleBinding(appName) {
  metadata+: {
    namespace: params.namespace,
  },
  subjects_: [ serviceAccount ],
  roleRef_: role,
};


// Deployment

local deployment = kube.Deployment(appName) {
  spec+: {
    replicas: params.replicaCount,
    template+: {
      spec+: {
        serviceAccountName: appName,
        securityContext: {
          seccompProfile: { type: 'RuntimeDefault' },
        },
        containers_:: {
          default: kube.Container(appName) {
            image: '%(registry)s/%(repository)s:%(tag)s' % params.images.fleetlock,
            env_:: {
              NAMESPACE: params.namespace,
            },
            ports_:: {
              http: { containerPort: 8080 },
            },
            resources: params.resources,
            securityContext: {
              allowPrivilegeEscalation: false,
              capabilities: { drop: [ 'ALL' ] },
            },
            livenessProbe: {
              httpGet: {
                scheme: 'HTTP',
                port: 'http',
                path: '/-/healthy',
              },
            },
          },
        },
      },
    },
  },
};

local service = kube.Service(appName) {
  target_pod:: deployment.spec.template,
  spec+: {
    clusterIP: params.service.clusterIP,
    sessionAffinity: 'None',
  },
};


// Define outputs below
{
  '00_namespace': namespace,
  '10_deployment': deployment,
  '10_service': service,
  '10_rbac': [ serviceAccount, clusterRole, clusterRoleBinding, role, roleBinding ],
}
