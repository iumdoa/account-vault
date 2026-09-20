import '../../domain/models/vault_entry.dart';
import '../../domain/repositories/vault_repository.dart';

/// In-memory mock repository populated with 20 fictional entries
/// covering network devices, websites, and infrastructure applications.
class MockVaultRepository implements VaultRepository {
  final List<VaultEntry> _entries = [];

  MockVaultRepository() {
    _seedFictionalData();
  }

  void _seedFictionalData() {
    final now = DateTime.utc(2026, 9, 18, 11, 0, 0);

    final initialData = [
      // 1. 网络设备
      VaultEntry(
        id: 'dev-01',
        title: '核心三层交换机 / 管理员',
        address: '192.168.1.1',
        username: 'admin',
        password: 'Switch_Admin_9#xL!2026',
        group: '网络设备',
        tags: ['cisco', 'switch', 'core', '机房A'],
        notes: '主数据中心核心交换机 01，高危权限，支持 SSHv2 登录。',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      VaultEntry(
        id: 'dev-02',
        title: '核心三层交换机 / 只读巡检',
        address: '192.168.1.1',
        username: 'monitor',
        password: 'Mon_Readonly_7*qP@2026',
        group: '网络设备',
        tags: ['cisco', 'switch', 'readonly', '巡检'],
        notes: '日常监控脚本与 Zabbix 自动化轮询采集账号。',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      VaultEntry(
        id: 'dev-03',
        title: '汇聚交换机 01 (楼宇B)',
        address: '192.168.1.2',
        username: 'netops',
        password: r'AggSwitch_B_8$uK^pass',
        group: '网络设备',
        tags: ['h3c', 'switch', 'aggregation'],
        notes: '办公楼 B 区汇聚接入，VLAN 10-50。',
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      VaultEntry(
        id: 'dev-04',
        title: '边缘防火墙主节点 (Active)',
        address: '10.0.0.1',
        username: 'secadmin',
        password: 'FW_Active_Master_99!&',
        group: '网络设备',
        tags: ['fortinet', 'firewall', 'ha'],
        notes: '外网出口双机热备主墙，管理端口 8443。',
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      VaultEntry(
        id: 'dev-05',
        title: '边缘防火墙备节点 (Standby)',
        address: '10.0.0.2',
        username: 'secadmin',
        password: 'FW_Standby_Slave_22%#',
        group: '网络设备',
        tags: ['fortinet', 'firewall', 'ha'],
        notes: '外网出口备用墙，同步主节点策略。',
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      VaultEntry(
        id: 'dev-06',
        title: '企业无线控制器 AC-01',
        address: '192.168.10.254',
        username: 'wlan_admin',
        password: 'Wlan_AC01_Access@2026',
        group: '网络设备',
        tags: ['ruijie', 'wifi', 'ap-controller'],
        notes: '全园区 AP 集中管控平台，SSID: Corp-Office。',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 8)),
      ),
      VaultEntry(
        id: 'dev-07',
        title: 'VPN 远程接入网关',
        address: 'vpn.internal.corp',
        username: 'remote_ops',
        password: 'VPN_Gateway_Token_78!~',
        group: '网络设备',
        tags: ['vpn', 'remote', 'gateway'],
        notes: '工程师紧急拨入通道，需结合动态证书验证。',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      VaultEntry(
        id: 'dev-08',
        title: '核心路由器 BGP 边界',
        address: '172.16.0.1',
        username: 'router_mgr',
        password: 'BGP_Edge_Rt_45^#Secure',
        group: '网络设备',
        tags: ['huawei', 'router', 'bgp'],
        notes: '连接电信与联通双链路上行。',
        createdAt: now.subtract(const Duration(days: 50)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),

      // 2. 网站与云服务
      VaultEntry(
        id: 'web-01',
        title: 'GitHub 组织团队负责人',
        address: 'https://github.com/company-org',
        username: 'devops-lead@company.local',
        password: 'ghp_MockTokenForDevOpsLead2026ABC',
        group: '开发工具',
        tags: ['github', 'git', 'ci-cd'],
        notes: '包含组织 Owner 与 Actions 管理权限。',
        createdAt: now.subtract(const Duration(days: 90)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      VaultEntry(
        id: 'web-02',
        title: 'AWS 生产云控制台',
        address: 'https://signin.aws.amazon.com',
        username: 'aws-infra-admin',
        password: 'AWS_Prod_Root_Password!2026',
        group: '云计算',
        tags: ['aws', 'cloud', 'prod'],
        notes: '生产账户，绑定虚拟 MFA 设备。',
        createdAt: now.subtract(const Duration(days: 80)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      VaultEntry(
        id: 'web-03',
        title: '阿里云企业控制台',
        address: 'https://homenew.console.aliyun.com',
        username: 'aliyun_enterprise_ops',
        password: 'Aliyun_RAM_SuperUser@888',
        group: '云计算',
        tags: ['aliyun', 'cloud', 'ram'],
        notes: '国内业务主节点，包含 OSS 与 ECS 集群权限。',
        createdAt: now.subtract(const Duration(days: 70)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      VaultEntry(
        id: 'web-04',
        title: '腾讯云大客户平台',
        address: 'https://cloud.tencent.com',
        username: 'tencent_cloud_admin',
        password: 'Tencent_QCloud_Sec_66^%',
        group: '云计算',
        tags: ['tencent', 'cloud', 'cdn'],
        notes: 'CDN 边缘加速与 DNS 解析管理。',
        createdAt: now.subtract(const Duration(days: 65)),
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
      VaultEntry(
        id: 'web-05',
        title: 'GitLab 内部私有代码站',
        address: 'https://gitlab.internal.net',
        username: 'gitlab-admin',
        password: 'GitLab_SelfHosted_Admin!2026',
        group: '开发工具',
        tags: ['gitlab', 'git', 'self-hosted'],
        notes: '自建私有代码仓库，LDAP 统一集成。',
        createdAt: now.subtract(const Duration(days: 100)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      VaultEntry(
        id: 'web-06',
        title: 'Jira 敏捷研发看板',
        address: 'https://jira.internal.net',
        username: 'pm_alice',
        password: r'Jira_Agile_Manager_33$#',
        group: '日常办公',
        tags: ['jira', 'project-management'],
        notes: '敏捷冲刺与缺陷追踪平台。',
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now.subtract(const Duration(days: 18)),
      ),
      VaultEntry(
        id: 'web-07',
        title: 'Confluence 知识库与文档',
        address: 'https://wiki.internal.net',
        username: 'tech_writer',
        password: 'Wiki_Doc_Author_88#@!',
        group: '日常办公',
        tags: ['wiki', 'docs'],
        notes: '技术架构演进与运维 Runbook 集合。',
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now.subtract(const Duration(days: 20)),
      ),

      // 3. 应用服务与数据库
      VaultEntry(
        id: 'app-01',
        title: 'MySQL 生产主库 (只读分析)',
        address: '10.0.10.51:3306',
        username: 'ro_analyst',
        password: 'MySQL_ReadOnly_Secure_55*',
        group: '数据存储',
        tags: ['database', 'mysql', 'readonly'],
        notes: 'BI 统计与数据查询专用，禁止执行写事务。',
        createdAt: now.subtract(const Duration(days: 35)),
        updatedAt: now.subtract(const Duration(hours: 8)),
      ),
      VaultEntry(
        id: 'app-02',
        title: 'PostgreSQL 业务核心库',
        address: '10.0.10.60:5432',
        username: 'app_backend',
        password: 'PG_Business_Master_Key!99',
        group: '数据存储',
        tags: ['database', 'postgres', 'backend'],
        notes: '用户中心微服务直连主库。',
        createdAt: now.subtract(const Duration(days: 35)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      VaultEntry(
        id: 'app-03',
        title: 'Redis 缓存集群哨兵',
        address: '10.0.20.11:6379',
        username: 'redis_monitor',
        password: 'Redis_Sentinel_Auth_66%#',
        group: '数据存储',
        tags: ['redis', 'cache', 'sentinel'],
        notes: '集群状态检测与高可用漂移监控。',
        createdAt: now.subtract(const Duration(days: 28)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      VaultEntry(
        id: 'app-04',
        title: '堡垒机生产跳板机',
        address: '192.168.100.10:2222',
        username: 'jumper_sec_dev',
        password: r'JumpServer_SSH_KeyPass_11$',
        group: '网络设备',
        tags: ['ssh', 'jumpserver', 'audit'],
        notes: '所有生产服务器唯一允许登入入口，全程审计录像。',
        createdAt: now.subtract(const Duration(days: 55)),
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
      VaultEntry(
        id: 'app-05',
        title: '本地 NAS 归档存储',
        address: '192.168.1.200',
        username: 'nas_backup_operator',
        password: 'Synology_Backup_Operator@89',
        group: '数据存储',
        tags: ['nas', 'storage', 'backup'],
        notes: '群晖 NAS 集中冷备目录，NFS/SMB 挂载点。',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];

    _entries.addAll(initialData);
  }

  @override
  Future<List<VaultEntry>> getAll() async {
    return List<VaultEntry>.unmodifiable(_entries);
  }

  @override
  Future<VaultEntry?> getById(String id) async {
    return _entries.cast<VaultEntry?>().firstWhere(
      (e) => e?.id == id,
      orElse: () => null,
    );
  }

  @override
  Future<void> save(VaultEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
  }

  @override
  Future<void> delete(String id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  Set<String> _protectedGroups = {};

  @override
  Set<String> get protectedGroups => Set.unmodifiable(_protectedGroups);

  @override
  Future<void> setProtectedGroups(Set<String> groups) async {
    _protectedGroups = Set<String>.from(groups);
  }
}
