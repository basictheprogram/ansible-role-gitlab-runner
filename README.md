GitLab Runner
=============

> **This is a fork of [riemers/ansible-gitlab-runner](https://github.com/riemers/ansible-gitlab-runner),
> maintained by Bob Tanner at Real Time Enterprises, Inc.
> The upstream project is no longer seeking an active maintainer. This fork tracks and extends it for
> continued personal and organizational use.**

This role will install the [official GitLab Runner](https://gitlab.com/gitlab-org/gitlab-runner)
(originally forked from haroldb, then maintained by riemers). It provides a simple, working
install across Linux, macOS, Windows, and Docker.

Requirements
------------

This role requires:

* Ansible 2.20 or higher
* Installed Ansible Galaxy collections listed in file [requirements.yml](requirements.yml)

Platform Notes
--------------

### Ubuntu 26.04 LTS (Resolute Raccoon)

GitLab has not yet published native packages for Ubuntu 26.04 Resolute Raccoon in the
`packages.gitlab.com` apt repository. The upstream feature request is tracked at
[gitlab-org/gitlab-runner#39449](https://gitlab.com/gitlab-org/gitlab-runner/-/work_items/39449).

**Current workaround (built into this role)**

When the role detects that the host's Ubuntu/Debian release is not in
`gitlab_runner_apt_supported_codenames`, it bypasses the packages.gitlab.com install
script (which auto-detects the OS codename and fails on Resolute) and instead manually
configures the apt repository using the codename defined in
`gitlab_runner_apt_codename_fallback` (default: `questing`, Ubuntu 25.10). This allows
the role to install the latest available GitLab Runner packages on Resolute Raccoon
hosts without any extra configuration.

No variables need to be set — the fallback is automatic.

**When native 26.04 packages are released**

Once GitLab publishes packages for Resolute Raccoon, add `resolute` to the
`gitlab_runner_apt_supported_codenames` list in your inventory or `group_vars`:

```yaml
gitlab_runner_apt_supported_codenames:
  - focal
  - jammy
  - noble
  - oracular
  - plucky
  - questing
  - resolute   # add this line once packages.gitlab.com supports it
  - buster
  - bullseye
  - bookworm
```

On the next Ansible run the role will detect `resolute` as a supported codename,
switch back to the standard script-based install path, and overwrite the manually
configured sources list. No other changes are needed.

Role Variables
--------------

- `gitlab_runner_package_name` - **As of GitLab 10.x**, the package name `gitlab-ci-multi-runner` has been renamed to `gitlab-runner`. To install a version earlier than 10.x, define the variable `gitlab_runner_package_name: gitlab-ci-multi-runner`.
- `gitlab_runner_wanted_version` or `gitlab_runner_package_version` - Use these to install a specific version of the GitLab Runner (by default, the latest version is installed).
  - On macOS and Windows, use `gitlab_runner_wanted_version: 12.4.1` (example).
  - On Linux, use `gitlab_runner_package_version` instead.
- `gitlab_runner_concurrent` - Defines the maximum number of jobs that can run concurrently. Defaults to the number of processor cores.
- `gitlab_runner_registration_token` - The GitLab registration token. If specified, this will register each runner with a GitLab server. **Note**: This token can only be used globally if `gitlab_runner_registration_token_type` is set to the deprecated `registration-token`. Otherwise, you must specify a `token` for each item in `gitlab_runner_runners`, as shown in the example playbook below. This token is deprecated in GitLab version 16.0 and will be removed in version 18.0.
- `gitlab_runner_registration_token_type` - Specifies the type of registration token to use for GitLab Runner registration:
  - Set to "authentication-token" to register the runner with the `--token` option (following the new workflow: https://docs.gitlab.com/ee/ci/runners/new_creation_workflow.html).
  - Set to "registration-token" to register the runner with the `--registration-token` option. This is deprecated in GitLab 16.0 but remains usable until it is removed in version 18.0.
  - For GitLab version 16.0 and above, it is recommended to specify a token for each runner in the `gitlab_runner_runners` section and set this variable to "authentication-token".
- `gitlab_runner_coordinator_url` - The GitLab coordinator URL. Defaults to `https://gitlab.com`.
- `gitlab_runner_sentry_dsn` - Enables tracking of system-level errors to Sentry.
- `gitlab_runner_listen_address` - Enables the `/metrics` endpoint for Prometheus scraping.
- `gitlab_runner_runners` - A list of GitLab runners to register and configure. By default, this is set to a single shell executor.
- `gitlab_runner_skip_package_repo_install` - Skips the installation of the APT or YUM repository (default: false). You should ensure that the necessary packages are available in your repository before running this role.
- `gitlab_runner_apt_supported_codenames` - List of Ubuntu/Debian release codenames that have native GitLab Runner packages in the official apt repository. Hosts whose codename is not in this list have the repository configured manually using `gitlab_runner_apt_codename_fallback`. See the Platform Notes section above for when and how to extend this list.
- `gitlab_runner_apt_codename_fallback` - Apt codename used when the host's release is not in `gitlab_runner_apt_supported_codenames`. Defaults to `questing` (Ubuntu 25.10).
- `gitlab_runner_apt_repo_codename` - Explicitly pin the apt repository to a specific codename, overriding auto-detection entirely. When set, the manual repo setup path is always used regardless of the host's release. Leave empty (default) to let the role decide.
- `gitlab_runner_keyring_path` - Path to the GitLab Runner repository GPG keyring file (default: `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg`).
  - Set to `/etc/apt/keyrings/runner_gitlab-runner-archive-keyring.gpg` (default) if using APT > 1.1
  - Set to `/etc/apt/trusted.gpg.d/runner_gitlab-runner.gpg` if using legacy APT < 1.1)
  - Set to custom path if you expect a different location for the keyring
- `gitlab_runner_config_update_mode` - Defines how configuration updates are applied:
  - Set to `by_config_toml` (default) to apply configuration changes directly by updating the `config.toml` file.
  - Set to `by_registering` if changes should be applied by unregistering and re-registering the runner when configuration changes.
  - Set to `by_template` if changes for all runners should directly be written in the `config.toml` file. This method is faster than `by_config_toml`. From the original `config.toml` it reads only 3 fields per runner: `id`, `token_obtained_at` and `token_expires_at`.
  All other content from the file is ignored
- `gitlab_unregister_runner_executors_which_are_not_longer_configured` - Set to `true` if executors should be unregistered from a runner when they are no longer configured in Ansible. Default: `false`.

See the [defaults/main.yml](https://github.com/riemers/ansible-gitlab-runner/blob/master/defaults/main.yml) file for a list of all possible options that can be passed to a runner registration command.

### Gitlab Runners cache
For each gitlab runner in gitlab_runner_runners you can set cache options. At the moment role support s3, azure and gcs types.
Example configurration for s3 can be:
```yaml
gitlab_runner:
  cache_type: "s3"
  cache_path: "cache"
  cache_shared: true
  cache_s3_server_address: "s3.amazonaws.com"
  cache_s3_access_key: "<access_key>"
  cache_s3_secret_key: "<secret_key>"
  cache_s3_bucket_name: "<bucket_name>"
  cache_s3_bucket_location: "eu-west-1"
  cache_s3_insecure: false
```

## Autoscale Runner Machine vars for AWS (optional)

- `MachineOptions: []` - Foremost you need to pass an array of dedicated vars in the machine_options to configure your scaling runner:

  + `amazonec2-access-key` and `amazonec2-secret-key` the keys of the dedicated IAM user with permission for EC2
  + `amazonec2-zone`
  + `amazonec2-region`
  + `amazonec2-vpc-id`
  + `amazonec2-subnet-id`
  + `amazonec2-use-private-address=true`
  + `amazonec2-security-group`
  + `amazonec2-instance-type`
  + you can also set `amazonec2-tags` to identify you instance more easily via aws-cli or the console.

- `MachineDriver` - which should be set to `amzonec2` when working on AWS
- `MachineName` - Name of the machine. It **must** contain `%s`, which will be replaced with a unique machine identifier.
- `IdleCount` - Number of machines, that need to be created and waiting in Idle state.
- `IdleTime` - Time (in seconds) for machine to be in Idle state before it is removed.
- `MaxGrowthRate` - The maximum number of machines that can be added to the runner in parallel. Default is 0 (no limit).
- `MaxBuilds` - Maximum job (build) count before machine is removed.
- `IdleScaleFactor` - (Experimental) The number of Idle machines as a factor of the number of machines currently in use. Must be in float number format. See the autoscale documentation for more details. Defaults to 0.0.
- `IdleCountMin` - 	Minimal number of machines that need to be created and waiting in Idle state when the IdleScaleFactor is in use. Default is 1.

### Read Sources
For details follow these links:

- [gitlab-docs/runner: advanced configuration: runners.machine section](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnersmachine-section)
- [gitlab-docs/runner: autoscale: supported cloud-providers](https://docs.gitlab.com/runner/configuration/autoscale.html#supported-cloud-providers)
- [gitlab-docs/runner: autoscale_aws: runners.machine section](https://docs.gitlab.com/runner/configuration/runner_autoscale_aws/#the-runnersmachine-section)

See the [config for more options](https://github.com/riemers/ansible-gitlab-runner/blob/master/tasks/register-runner.yml)

Example Playbook
----------------
```yaml
- hosts: all
  become: true
  vars_files:
    - vars/main.yml
  roles:
    - { role: riemers.gitlab-runner }
```

Inside `vars/main.yml`
```yaml
gitlab_runner_coordinator_url: https://gitlab.com
gitlab_runner_registration_token: '12341234'
gitlab_runner_runners:
  - name: 'Example Docker GitLab Runner'
    # token is an optional override to the global gitlab_runner_registration_token
    token: 'abcd'
    # url is an optional override to the global gitlab_runner_coordinator_url
    url: 'https://my-own-gitlab.mydomain.com'
    request_concurrency: 2
    executor: docker
    docker_image: 'alpine'
    tags:
      - node
      - ruby
      - mysql
    docker_volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "/cache"
    extra_configs:
      runners.docker:
        memory: 512m
        allowed_images: ["ruby:*", "python:*", "php:*"]
      runners.docker.sysctls:
        net.ipv4.ip_forward: "1"
```

## autoscale setup on AWS
how `vars/main.yml` would look like, if you setup an autoscaling GitLab-Runner on AWS:

```yaml
gitlab_runner_registration_token: 'HUzTMgnxk17YV8Rj8ucQ'
gitlab_runner_coordinator_url: 'https://gitlab.com'
gitlab_runner_runners:
  - name: 'Example autoscaling GitLab Runner'
    state: present
    # token is an optional override to the global gitlab_runner_registration_token
    token: 'HUzTMgnxk17YV8Rj8ucQ'
    executor: 'docker+machine'
    # Maximum number of jobs to run concurrently on this specific runner.
    # Defaults to 0, simply means don't limit.
    concurrent_specific: '0'
    docker_image: 'alpine'
    # Indicates whether this runner can pick jobs without tags.
    run_untagged: true
    machine_IdleCount: 1
    machine_IdleTime: 1800
    machine_MaxBuilds: 10
    machine_MachineDriver: 'amazonec2'
    machine_MachineName: 'git-runner-%s'
    machine_MachineOptions: ["amazonec2-access-key={{ lookup('env','AWS_IAM_ACCESS_KEY') }}", "amazonec2-secret-key={{ lookup('env','AWS_IAM_SECRET_KEY') }}", "amazonec2-zone={{ lookup('env','AWS_EC2_ZONE') }}", "amazonec2-region={{ lookup('env','AWS_EC2_REGION') }}", "amazonec2-vpc-id={{ lookup('env','AWS_VPC_ID') }}", "amazonec2-subnet-id={{ lookup('env','AWS_SUBNET_ID') }}", "amazonec2-use-private-address=true", "amazonec2-tags=gitlab-runner", "amazonec2-security-group={{ lookup('env','AWS_EC2_SECURITY_GROUP') }}", "amazonec2-instance-type={{ lookup('env','AWS_EC2_INSTANCE_TYPE') }}"]
    machine_autoscaling:
      - Periods: ["* * 7-18 * * mon-fri *"]
        Timezone: "UTC"
        IdleCount: 3
        IdleTime: 900
      - Periods: ["* * * * * sat,sun *"]
        Timezone: "UTC"
        IdleCount: 0
        IdleTime: 300
```

### NOTE
from https://docs.gitlab.com/runner/executors/docker_machine.html:

>The **first time** you’re using Docker Machine, it’s best to execute **manually** `docker-machine create...` with your chosen driver and **all options from the MachineOptions** section. This will set up the Docker Machine environment properly and will also be a good validation of the specified options. After this, you *can destroy the machine* with `docker-machine rm [machine_name]` and start the Runner.

Example:

```docker-machine create -d amazonec2 --amazonec2-zone=a --amazonec2-region=us-east-1 --amazonec2-vpc-id=vpc-11111111 --amazonec2-subnet-id=subnet-1111111 --amazonec2-use-private-address=true --amazonec2-tags=gitlab-runner --amazonec2-instance-type=t3.medium test

docker-machine rm test
```

Run As A Different User
-----------------------
To run the Gitlab Runner as a different user (rather than the default `gitlab-runner` user), there is a workaround requiring a little
extra Ansible to be run. See https://github.com/riemers/ansible-gitlab-runner/issues/277 for details.

Maintainer
----------
This fork is maintained by **Bob Tanner** &lt;tanner@real-time.com&gt; at Real Time Enterprises, Inc.
Issues and PRs for this fork should be filed here, not upstream.

Contributors
------------
A full list of upstream contributors is [here](https://github.com/riemers/ansible-gitlab-runner/pulls?q=is%3Apr+is%3Aclosed).

- Erik-jan Riemers (original maintainer of riemers/ansible-gitlab-runner)
- Gastrofix for adding Mac Support
- Matthias Schmieder for adding Windows Support
- dniwdeus & rosenstrauch for adding AWS autoscale option
- oscillate123 for fixing Windows config.toml idempotency
- [cchaudier](https://github.com/cchaudier) for fixing changing the version of a package which is on the apt hold list
