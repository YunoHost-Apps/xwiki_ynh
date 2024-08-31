#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

super_admin_config='#'
systemd_match_start_line='oxtjl.NotifyListener:main: ----------------------------------'
flavor_version='16.3.1'
ldap_version='9.15.2'

if [ $install_standard_flavor -eq 1 ]; then
    distribution_default_ui="distribution.defaultUI=org.xwiki.platform:xwiki-platform-distribution-flavor-mainwiki/$flavor_version"
else
    distribution_default_ui='#'
fi

if [ $path == '/' ]; then
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
    ln -f /etc/"$app"/xwiki_conf.cfg "$web_inf_path"/xwiki.cfg
    chmod 400 /etc/"$app"/xwiki_conf.cfg
    chown "$app:$app" /etc/"$app"/xwiki_conf.cfg
}

disable_super_admin() {
    super_admin_config='#'
    ynh_config_add --template=xwiki.cfg --destination=/etc/"$app"/xwiki_conf.cfg
    ln -f /etc/"$app"/xwiki_conf.cfg "$web_inf_path"/xwiki.cfg
    chmod 400 /etc/"$app"/xwiki_conf.cfg
    chown "$app:$app" /etc/"$app"/xwiki_conf.cfg
}

install_exension() {
    local extension_id=$1
    local extension_version=$2
    local temp_dir=$(mktemp -d)
    local job_id=$(ynh_string_random)
    local xq=$install_dir/xq_tool/xq
    local curl='curl --silent --show-error'
    local extension_name_path=$(echo ${extension_id//./%2E} | sed 's|:|%3A|g')
    local extension_version_path=${extension_version//./%2E}

    if [ -e "$data_dir/extension/repository/$extension_name_path/$extension_version_path" ]; then
        # Return if extension is already installed
        return 0
    fi

    local status_raw
    local state_request

    chmod 700 "$temp_dir"
    chown root:root "$temp_dir"

    ynh_config_add --template=install_extensions.xml --destination="$temp_dir"/install_extensions.xml
    status_raw=$($curl -i --user "superadmin:$super_admin_pwd" -X PUT -H 'Content-Type: text/xml' "http://127.0.0.1:$port/${path2}rest/jobs?jobType=install&async=true" --upload-file $temp_dir/install_extensions.xml)
    state_request=$(echo "$status_raw" | $xq -x '//jobStatus/ns2:state')

    while true; do
        sleep 5

        status_raw=$($curl --user "superadmin:$super_admin_pwd" -X GET -H 'Content-Type: text/xml' "http://127.0.0.1:$port/${path2}rest/jobstatus/extension/action/$job_id")
        state_request=$(echo "$status_raw" | $xq -x '//jobStatus/state')

        if [ -z "$state_request" ]; then
            ynh_die "Invalid answer: '$status_raw'"
        elif [ "$state_request" == FINISHED ]; then
            # Check if error happen
            error_msg=$(echo "$status_raw" | $xq -x '//jobStatus/errorMessage')
            if [ -z "$error_msg" ]; then
                break
            else
                ynh_die "Error while installing extension '$extension_id'. Error: $error_msg"
            fi
        elif [ "$state_request" != RUNNING ]; then
            ynh_die "Invalid status '$state_request'"
        fi
    done
}

wait_xwiki_started() {
    local res='meta http-equiv="refresh" content="1"'
    local curl='curl --silent --show-error'

    while echo "$res" | grep -q 'meta http-equiv="refresh" content="1"'; do
        res=$($curl "http://127.0.0.1:$port/${path2}bin/view/Main/")
        sleep 10
    done
}

wait_for_flavor_install() {
    local status_header

    # Need to call main page to start xwiki service
    wait_xwiki_started

    while true; do
        status_header="$(curl --silent --show-error -I "http://127.0.0.1:$port/${path2}bin/view/Main/")"
        if ! echo "$status_header" | grep -q -E 'Location:[[:space:]].*/Distribution\?xredirect='; then
            break
        fi
        sleep 10
    done
}

install_source() {
    ynh_setup_source --dest_dir="$install_dir" --full_replace
    ynh_setup_source --dest_dir="$install_dir"/webapps/xwiki/WEB-INF/lib/ --source_id=jdbc
    ynh_setup_source --dest_dir="$install_dir"/xq_tool --source_id=xq_tool

    ynh_safe_rm "$install_dir"/webapps/xwiki/WEB-INF/xwiki.cfg
    ynh_safe_rm "$install_dir"/webapps/xwiki/WEB-INF/xwiki.properties
    ynh_safe_rm "$install_dir"/webapps/root

    ln -s /var/log/"$app" "$install_dir"/logs

    if $install_on_root; then
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

    # Note that using /etc/xwiki/xwiki.cfg or /etc/xwiki/xwiki.properties is hard coded on the application
    # And using this break multi instance feature so we must use an other path
    # Note that symlink don't work. So use hard link instead.
    ln -f /etc/$app/xwiki_conf.cfg "$web_inf_path"/xwiki.cfg
    ln -f /etc/$app/xwiki_conf.properties "$web_inf_path"/xwiki.properties
}

set_permissions() {
    #REMOVEME? Assuming the install dir is setup using ynh_setup_source, the proper chmod/chowns are now already applied and it shouldn't be necessary to tweak perms | chmod -R u+rwX,o-rwx "$install_dir"
    #REMOVEME? Assuming the install dir is setup using ynh_setup_source, the proper chmod/chowns are now already applied and it shouldn't be necessary to tweak perms | chown -R "$app:$app" "$install_dir"
    chmod -R u=rwX,g=rX,o= /etc/"$app"
    chown -R "$app:$app" /etc/"$app"

    #REMOVEME? Assuming ynh_config_add_logrotate is called, the proper chmod/chowns are now already applied and it shouldn't be necessary to tweak perms | chown "$app:$app" -R /var/log/"$app"
    #REMOVEME? Assuming ynh_config_add_logrotate is called, the proper chmod/chowns are now already applied and it shouldn't be necessary to tweak perms | chmod u=rwX,g=rX,o= -R /var/log/"$app"

    find "$data_dir" \(   \! -perm -o= \
                    -o \! -user "$app" \
                    -o \! -group "$app" \) \
                -exec chown "$app:$app" {} \; \
                -exec chmod u=rwX,g=rX,o= {} \;
}
