#!/bin/bash

set -eu

readonly app_name=xwiki

source auto_update_config.sh

get_from_manifest() {
    result=$(python3 <<EOL
import toml
import json
with open("../manifest.toml", "r") as f:
    file_content = f.read()
loaded_toml = toml.loads(file_content)
json_str = json.dumps(loaded_toml)
print(json_str)
EOL
    )
    echo "$result" | jq -r "$1"
}

get_remote_version_from_nexus() {
    curl https://nexus.xwiki.org/nexus/content/groups/public/"$1" |
            xq -x '//metadata/versioning/versions' |
            sed -E 's|\s*(.*)\s*|\1|g' |
            grep -v '\-rc-' |
            grep -v '\-milestone-' |
            grep -v '^$' |
            python3 -c 'import sys
from packaging.version import Version
versions = sys.stdin.read().splitlines()
versions.sort(key=Version)
print(versions[-1])'
}

check_app_version() {
    local app_remote_version=$(get_remote_version_from_nexus org/xwiki/platform/xwiki-platform-distribution-jetty-hsqldb/maven-metadata.xml)
    ldap_version=$(get_remote_version_from_nexus org/xwiki/contrib/ldap/ldap-authenticator/maven-metadata.xml)
    jdbc_version=$(curl 'https://api.github.com/repos/pgjdbc/pgjdbc/releases/latest' -H 'Host: api.github.com' --compressed | jq -r ".tag_name" | cut -dL -f2)

    ## Check if new build is needed
    if [[ "$app_version" != "$app_remote_version" ]]
    then
        app_version="$app_remote_version"
        return 0
    else
        return 1
    fi
}

upgrade_app() {
    (
        set -eu

        prev_sha256sum_main=$(get_from_manifest ".resources.sources.main.sha256")
        prev_sha256sum_jdbc=$(get_from_manifest ".resources.sources.jdbc.sha256")

        wget -O main.zip "https://nexus.xwiki.org/nexus/content/groups/public/org/xwiki/platform/xwiki-platform-distribution-jetty-hsqldb/$app_version/xwiki-platform-distribution-jetty-hsqldb-$app_version.zip"
        sha256sum_main=$(sha256sum main.zip | cut -d' ' -f1)
        rm main.zip
        wget -O jdbc.jar "https://jdbc.postgresql.org/download/postgresql-$jdbc_version.jar"
        sha256sum_jdbc=$(sha256sum jdbc.jar | cut -d' ' -f1)

        # Update manifest
        sed -r -i 's|version = "[[:alnum:].]{4,8}~ynh[[:alnum:].]{1,2}"|version = "'"${app_version}"'~ynh1"|' ../manifest.toml
        sed -r -i "s|xwiki-platform-distribution-jetty-hsqldb/[[:alnum:].]{4,10}/xwiki-platform-distribution-jetty-hsqldb-[[:alnum:].]{4,10}.zip|xwiki-platform-distribution-jetty-hsqldb/$app_version/xwiki-platform-distribution-jetty-hsqldb-$app_version.zip|" ../manifest.toml
        sed -r -i 's|postgresql-[[:alnum:].]{4,10}\.jar|postgresql-'"${jdbc_version}"'.jar|' ../manifest.toml
        sed -r -i "s|$prev_sha256sum_main|$sha256sum_main|" ../manifest.toml
        sed -r -i "s|$prev_sha256sum_jdbc|$sha256sum_jdbc|" ../manifest.toml
        sed -r -i "s|ldap_version='[[:alnum:].]{3,9}'|ldap_version='$ldap_version'|" ../scripts/_common.sh

        git commit -a -m "Upgrade $app_name to $app_version"
        git push gitea auto_update:auto_update
    ) 2>&1 | tee "${app_name}_build_temp.log"
    return "${PIPESTATUS[0]}"
}

app_prev_version="$(get_from_manifest ".version" |  cut -d'~' -f1)"
app_version="$app_prev_version"

if check_app_version
then
    set +eu
    upgrade_app
    res=$?
    set -eu
    if [ $res -eq 0 ]; then
        result="Success"
    else
        result="Failed"
    fi
    msg="Build: $app_name version $app_version"

    echo "$msg" | mail.mailutils --content-type="text/plain; charset=UTF-8" -A "${app_name}_build_temp.log" -s "Autoupgrade $app_name : $result" "$notify_email"
fi
