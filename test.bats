#!/usr/bin/env bats

setup(){
  cat /dev/null >| mockCalledWith

  declare -A -p MOCK_RETURNS=(
  ['/usr/local/bin/docker']=""
  ) > mockReturns

  export GITHUB_REF='refs/heads/master'
  export INPUT_USERNAME='USERNAME'
  export INPUT_PASSWORD='PASSWORD'
  export INPUT_NAME='my/repository'
}

teardown() {
  unset INPUT_SEMVER
  unset INPUT_DOCKERFILE
  unset INPUT_REGISTRY
  unset INPUT_PULL_REQUESTS
  unset MOCK_ERROR_CONDITION
}

@test "with semver it pushes tags using the semver version" {
  export INPUT_SEMVER="1.2.5"

  run /entrypoint.sh

  expectStdOut "
::debug file=entrypoint.sh::Starting docker build  -t my/repository:latest .
::debug file=entrypoint.sh::Finished building my/repository:latest
::debug file=entrypoint.sh::Starting docker push my/repository:latest
::debug file=entrypoint.sh::Finished pushing my/repository:latest
::debug file=entrypoint.sh::Starting docker tag my/repository:latest my/repository:1.2.5
::debug file=entrypoint.sh::Finished tagging my/repository:latest my/repository:1.2.5
::debug file=entrypoint.sh::Starting docker push my/repository:1.2.5
::debug file=entrypoint.sh::Finished pushing my/repository:1.2.5
::debug file=entrypoint.sh::Starting docker tag my/repository:latest my/repository:1
::debug file=entrypoint.sh::Finished tagging my/repository:latest my/repository:1
::debug file=entrypoint.sh::Starting docker push my/repository:1
::debug file=entrypoint.sh::Finished pushing my/repository:1
::debug file=entrypoint.sh::Starting docker tag my/repository:latest my/repository:1.2
::debug file=entrypoint.sh::Finished tagging my/repository:latest my/repository:1.2
::debug file=entrypoint.sh::Starting docker push my/repository:1.2
::debug file=entrypoint.sh::Finished pushing my/repository:1.2
::set-output name=tag::1.2.5"

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin
/usr/local/bin/docker build -t my/repository:latest .
/usr/local/bin/docker push my/repository:latest
/usr/local/bin/docker tag my/repository:latest my/repository:1.2.5
/usr/local/bin/docker push my/repository:1.2.5
/usr/local/bin/docker tag my/repository:latest my/repository:1
/usr/local/bin/docker push my/repository:1
/usr/local/bin/docker tag my/repository:latest my/repository:1.2
/usr/local/bin/docker push my/repository:1.2
/usr/local/bin/docker logout"
}

@test "it pushes to another registry and adds the hostname" {
  export INPUT_REGISTRY='my.Registry.io'

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin my.Registry.io
/usr/local/bin/docker build -t my.Registry.io/my/repository:latest .
/usr/local/bin/docker push my.Registry.io/my/repository:latest
/usr/local/bin/docker tag my.Registry.io/my/repository:latest my.Registry.io/my/repository:
/usr/local/bin/docker push my.Registry.io/my/repository:
/usr/local/bin/docker logout"
}

@test "it pushes to another registry and is ok when the hostname is already present" {
  export INPUT_REGISTRY='my.Registry.io'
  export INPUT_NAME='my.Registry.io/my/repository'

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin my.Registry.io
/usr/local/bin/docker build -t my.Registry.io/my/repository:latest .
/usr/local/bin/docker push my.Registry.io/my/repository:latest
/usr/local/bin/docker tag my.Registry.io/my/repository:latest my.Registry.io/my/repository:
/usr/local/bin/docker push my.Registry.io/my/repository:
/usr/local/bin/docker logout"
}

@test "it pushes to another registry and removes the protocol from the hostname" {
  export INPUT_REGISTRY='https://my.Registry.io'
  export INPUT_NAME='my/repository'

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin my.Registry.io
/usr/local/bin/docker build -t my.Registry.io/my/repository:latest .
/usr/local/bin/docker push my.Registry.io/my/repository:latest
/usr/local/bin/docker tag my.Registry.io/my/repository:latest my.Registry.io/my/repository:
/usr/local/bin/docker push my.Registry.io/my/repository:
/usr/local/bin/docker logout"
}

function expectStdOut() {
  echo "Expected: |$1|
  Got: |$output|"
  [ "$output" = "$1" ]
}

function expectMockCalled() {
  local mockCalledWith=$(cat mockCalledWith)
  echo "Expected: |$1|
  Got: |$mockCalledWith|"
  [ "$mockCalledWith" = "$1" ]
}
