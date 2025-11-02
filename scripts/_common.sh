#!/bin/bash

source /usr/share/yunohost/helpers

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

readonly systemd_match_start_line='oxtjl.NotifyListener:main: ----------------------------------'
readonly flavor_version="$(ynh_app_upstream_version)"
readonly ldap_version='9.16.1'
readonly xq="$install_dir/xq_tool/xq"

super_admin_config='#'

if [ "$path" == '/' ]; then
    install_on_root=true
    path2=''
    path3=''
    web_inf_path="$install_dir"/webapps/root/WEB-INF
else
    install_on_root=false
    path2=${path/#\//}/ # path=/xwiki -> xwiki/
    path3=${path/#\//} # path=/xwiki -> xwiki
    web_inf_path="$install_dir/webapps$path/WEB-INF"
fi

enable_super_admin() {
    super_admin_pwd=$(ynh_string_random)
    super_admin_config="xwiki.superadminpassword=$super_admin_pwd"
    ynh_config_add --template=xwiki.cfg --destination=/etc/"$app"/xwiki_conf.cfg
    chmod 400 /etc/"$app"/xwiki_conf.cfg
    chown "$app:$app" /etc/"$app"/xwiki_conf.cfg
}

disable_super_admin() {
    super_admin_config='#'
    ynh_config_add --template=xwiki.cfg --destination=/etc/"$app"/xwiki_conf.cfg
    chmod 400 /etc/"$app"/xwiki_conf.cfg
    chown "$app:$app" /etc/"$app"/xwiki_conf.cfg
}

install_exension() {
    local extension_id=$1
    local extension_version=$2
    local temp_dir=$(mktemp -d)
    local job_id=$(ynh_string_random -l 5)

    local extension_name_path=$(echo ${extension_id//./%2E} | sed 's|:|%3A|g')
    local extension_version_path=${extension_version//./%2E}
    local file_path="$data_dir/extension/repository/$extension_name_path/$extension_version_path/$extension_name_path-$extension_version_path.xed"

    if [ -e "$file_path" ]; then
        root_install_date="$($xq -x '//extension/properties/installed.root/date' "$file_path")"
        main_wiki_install_date="$($xq -x '//extension/properties/installed.namespaces/xwiki' "$file_path")"

        if [ -n "$root_install_date" ] || [ -n "$main_wiki_install_date" ]; then
            # Cancel install as the extension is already installed
            return 0
        fi
    fi

    chmod 700 "$temp_dir"
    chown root:root "$temp_dir"

    ynh_config_add --jinja --template=install_extension_request.xml --destination="$temp_dir/install_extension_request.xml"

    execute_job "extension/action/$extension_id/wiki:xwiki/$extension_version/$job_id" "$temp_dir/install_extension_request.xml"
}

install_standard_flavor() {
    local temp_dir=$(mktemp -d)
    local job_id=$(ynh_string_random -l 5)

    local extension_version_path=${flavor_version//./%2E}
    local file_path="$data_dir/extension/repository/org%2Exwiki%2Eplatform%3Axwiki-platform-distribution-flavor-mainwiki/$extension_version_path/org%2Exwiki%2Eplatform%3Axwiki-platform-distribution-flavor-mainwiki-$extension_version_path.xed"

    if [ -e "$file_path" ]; then
        main_wiki_install_date="$($xq -x '//extension/properties/installed.namespaces/xwiki' "$file_path")"

        if [ -n "$main_wiki_install_date" ]; then
            # Cancel install as the extension is already installed
            return 0
        fi
    fi

    chmod 700 "$temp_dir"
    chown root:root "$temp_dir"

    ynh_config_add --jinja --template=install_flavor_request.xml --destination="$temp_dir/install_flavor_request.xml"

    execute_job "extension/action/org.xwiki.platform:xwiki-platform-distribution-flavor-mainwiki/wiki:xwiki/$flavor_version/$job_id" "$temp_dir/install_flavor_request.xml"
}

execute_job() {
    local job_path=$1
    local job_file=$2
    local curl='curl --silent --show-error --retry-delay 5 --retry 4'

    local status_raw
    local state_request
    local error_msg

    $curl -i --user "superadmin:$super_admin_pwd" -X PUT -H 'Content-Type: text/xml' "http://127.0.0.1:$port/${path2}rest/jobs?jobType=install&async=true" --upload-file "$job_file"

    while true; do
        sleep 10

        status_raw="$($curl --user "superadmin:$super_admin_pwd" -X GET -H 'Content-Type: text/xml' "http://127.0.0.1:$port/${path2}rest/jobstatus/$job_path")"
        state_request="$(echo "$status_raw" | $xq -x '//jobStatus/state')"

        if [ -z "$state_request" ]; then
            ynh_die "Invalid answer: '$status_raw'"
        elif [ "$state_request" == FINISHED ]; then
            # Check if error happen
            error_msg="$(echo "$status_raw" | $xq -x '//jobStatus/errorMessage')"
            if [ -z "$error_msg" ]; then
                break
            else
                ynh_die "Error while running job $job_path"
            fi
        elif [ "$state_request" != RUNNING ]; then
            ynh_die "Invalid status '$state_request'"
        fi
    done
}

install_source() {
    ynh_setup_source --dest_dir="$install_dir" --full_replace
    ynh_setup_source --dest_dir="$install_dir"/webapps/xwiki/WEB-INF/lib/ --source_id=jdbc
    ynh_setup_source --dest_dir="$install_dir"/xq_tool --source_id=xq_tool

    ynh_safe_rm "$install_dir"/webapps/xwiki/WEB-INF/xwiki.cfg
    ynh_safe_rm "$install_dir"/webapps/xwiki/WEB-INF/xwiki.properties

    ln -s /var/log/"$app" "$install_dir"/logs
    ln -s /etc/"$app"/xwiki_conf.cfg "$install_dir"/webapps/xwiki/WEB-INF/xwiki.cfg
    ln -s /etc/"$app"/xwiki_conf.properties "$install_dir"/webapps/xwiki/WEB-INF/xwiki.properties
    cp ../conf/jetty-web.xml "$install_dir"/webapps/xwiki/WEB-INF/jetty-web.xml
    ynh_replace --match='<name>XWiki Jetty HSQLDB</name>' \
                --replace='<name>XWiki YunoHost Jetty PostgreSQL</name>' \
                --file="$install_dir/webapps/xwiki/META-INF/extension.xed"

    if $install_on_root; then
        ynh_safe_rm "$install_dir"/webapps/root
        mv "$install_dir"/webapps/xwiki "$install_dir"/webapps/root
    elif [ "$path" == /root ]; then
        ynh_die 'Path "/root" not supported'
    elif [ "$path" != /xwiki ]; then
        mv "$install_dir"/webapps/xwiki "$install_dir/webapps$path"
    fi
}

add_config() {
    ynh_config_add --template=hibernate.cfg.xml --destination=/etc/"$app"/hibernate.cfg.xml
    ynh_config_add --template=xwiki.cfg --destination=/etc/"$app"/xwiki_conf.cfg
    ynh_config_add --template=xwiki.properties --destination=/etc/"$app"/xwiki_conf.properties
}

set_permissions() {
    chmod -R u+rwX,g+rX-w,o= "$install_dir"
    chown -R "$app:$app" "$install_dir"
    chmod -R u=rwX,g=rX,o= /etc/"$app"
    chown -R "$app:$app" /etc/"$app"

    chown "$app:$app" -R /var/log/"$app"
    chmod u=rwX,g=rX,o= -R /var/log/"$app"

    chmod u=rwx,g=rx,o= "$data_dir"
    find "$data_dir" \(   \! -perm -o= \
                    -o \! -user "$app" \
                    -o \! -group "$app" \) \
                -exec chown "$app:$app" {} \; \
                -exec chmod u=rwX,g=rX,o= {} \;
}
