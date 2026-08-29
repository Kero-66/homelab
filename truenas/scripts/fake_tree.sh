find /mnt/.ix-apps/app_mounts/dockhand/data/git-repos -maxdepth 3 -type d | sort | awk -F/ '
NR==1 {print $0; next} 
{
    depth = NF - 7
    indent = ""
    for (i=0; i<depth; i++) indent = indent "    "
    print indent "└── " $NF
}'
