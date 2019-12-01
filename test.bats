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
  export GITHUB_REF='refs/tags/myRelease'
  export INPUT_SEMVER="1.2.5"

  run /entrypoint.sh

  expectStdOut "
::set-output name=tag::1.2.5"

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin
/usr/local/bin/docker build -t my/repository:myRelease .
/usr/local/bin/docker push my/repository:myRelease
/usr/local/bin/docker logout"
}

@test "it pushes to another registry and adds the hostname" {
  export INPUT_REGISTRY='my.Registry.io'

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin my.Registry.io
/usr/local/bin/docker build -t my.Registry.io/my/repository:latest .
/usr/local/bin/docker push my.Registry.io/my/repository:latest
/usr/local/bin/docker logout"
}

@test "it pushes to another registry and is ok when the hostname is already present" {
  export INPUT_REGISTRY='my.Registry.io'
  export INPUT_NAME='my.Registry.io/my/repository'

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin my.Registry.io
/usr/local/bin/docker build -t my.Registry.io/my/repository:latest .
/usr/local/bin/docker push my.Registry.io/my/repository:latest
/usr/local/bin/docker logout"
}

@test "it pushes to another registry and removes the protocol from the hostname" {
  export INPUT_REGISTRY='https://my.Registry.io'
  export INPUT_NAME='my/repository'

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin https://my.Registry.io
/usr/local/bin/docker build -t my.Registry.io/my/repository:latest .
/usr/local/bin/docker push my.Registry.io/my/repository:latest
/usr/local/bin/docker logout"
}

@test "it pushes to the tag if configured in the name" {
  export INPUT_NAME='my/repository:custom-tag'

  run /entrypoint.sh

  expectStdOut "
::set-output name=tag::custom-tag"

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin
/usr/local/bin/docker build -t my/repository:custom-tag .
/usr/local/bin/docker push my/repository:custom-tag
/usr/local/bin/docker logout"
}

@test "it uses buildargs for building, if configured" {
  export INPUT_BUILDARGS='MY_FIRST,MY_SECOND'

  run /entrypoint.sh

  expectStdOut "
::add-mask::MY_FIRST
::add-mask::MY_SECOND
::set-output name=tag::latest"

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin
/usr/local/bin/docker build --build-arg MY_FIRST --build-arg MY_SECOND -t my/repository:latest .
/usr/local/bin/docker push my/repository:latest
/usr/local/bin/docker logout"
}

@test "it uses buildargs for a single variable" {
  export INPUT_BUILDARGS='MY_ONLY'

  run /entrypoint.sh

  expectStdOut "
::add-mask::MY_ONLY
::set-output name=tag::latest"

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin
/usr/local/bin/docker build --build-arg MY_ONLY -t my/repository:latest .
/usr/local/bin/docker push my/repository:latest
/usr/local/bin/docker logout"
}

@test "it errors when with.name was not set" {
  unset INPUT_NAME

  run /entrypoint.sh

  local expected="Unable to find the name. Did you set with.name?"
  echo $output
  [ "$status" -eq 1 ]
  echo "$output" | grep "$expected"
}

@test "it errors when with.username was not set" {
  unset INPUT_USERNAME

  run /entrypoint.sh

  local expected="Unable to find the username. Did you set with.username?"
  echo $output
  [ "$status" -eq 1 ]
  echo "$output" | grep "$expected"
}

@test "it errors when with.password was not set" {
  unset INPUT_PASSWORD

  run /entrypoint.sh

  local expected="Unable to find the password. Did you set with.password?"
  echo $output
  [ "$status" -eq 1 ]
  echo "$output" | grep "$expected"
}

@test "it errors when the working directory is configured but not present" {
  export INPUT_WORKDIR='mySubDir'

  run /entrypoint.sh

  [ "$status" -eq 2 ]
}

@test "it can set a custom context" {
  export GITHUB_REF='refs/heads/master'
  export INPUT_CONTEXT='/myContextFolder'

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin
/usr/local/bin/docker build -t my/repository:latest /myContextFolder
/usr/local/bin/docker push my/repository:latest
/usr/local/bin/docker logout"
}

@test "it can set a custom context when building snapshot" {
  export GITHUB_REF='refs/heads/master'
  export INPUT_CONTEXT='/myContextFolder'
  export GITHUB_SHA='12169ed809255604e557a82617264e9c373faca7'
  export INPUT_SNAPSHOT='true'

  declare -A -p MOCK_RETURNS=(
  ['/usr/local/bin/docker']=""
  ['/usr/bin/date']="197001010101"
  ) > mockReturns

  run /entrypoint.sh

  expectMockCalled "/usr/local/bin/docker login -u USERNAME --password-stdin
/usr/bin/date +%Y%m%d%H%M%S
/usr/local/bin/docker build -t my/repository:latest -t my/repository:19700101010112169e /myContextFolder
/usr/local/bin/docker push my/repository:latest
/usr/local/bin/docker push my/repository:19700101010112169e
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
