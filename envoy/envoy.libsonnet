local socket_address(addr, port) = {
  socket_address: {
    address: addr,
    port_value: port,
  },
};
local http_connection_manager(stat_prefix, cluster) = {
  name: 'envoy.filters.network.http_connection_manager',
  typed_config: {
    '@type': 'type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager',
    stat_prefix: stat_prefix,
    codec_type: 'AUTO',
    route_config: {
      name: cluster,
      virtual_hosts: [
        {
          name: cluster,
          domains: ['*'],
          routes: [
            {
              match: {
                prefix: '/',
              },
              route: {
                cluster: cluster,
              },
            },
          ],
        },
      ],
    },
  },
  http_filters: [
    {
      name: 'envoy.filters.http.router',
    },
  ],
};
local cluster(name, address, port) = {
  name: name,
  connect_timeout: '0.25s',
  type: 'STATIC',
  lb_policy: 'ROUND_ROBIN',
  load_assignment: {
    cluster_name: name,
    endpoints: [
      {
        lb_endpoints: [
          {
            endpoint: {
              address: socket_address(address, port),
            },
          },
        ],
      },
    ],
  },
};
local base(nginx_addr) = {
  admin: {
    address: socket_address('0.0.0.0', 9901),
  },
  static_resources: {
    listeners: [
      {
        name: 'satymathbot',
        address: socket_address('0.0.0.0', 8080),
        filter_chains: [
          {
            filters: [
                http_connection_manager('ingress_http', 'satymathbot'),
            ],
          },
        ],
      },
    ],
    clusters: [
        cluster('satymathbot', nginx_addr, 80),
    ],
  },
};
{
    prod: base('127.0.0.1'),
    dev: base('192.168.1.2'),
}