#!/bin/sh

echo "After complete work input: exit"
# docker exec -it $(cat docker-compose.yml | grep -i container_name | awk -F ":" '{print($2)}' | awk '{print($1)}') bash
items=$(cat docker-compose.yml | grep -i container_name | awk -F ":" '{print($2)}' | awk '{print($1)}')

for item in $items; do

    echo  Are you want connect to: $item
    
    select yn in "Yes" "No"; do

        case $yn in

            Yes) container=$item; break;;
            No) $SETCOLOR_RED; echo -en "aborting... that was close."; $SETCOLOR_WHITE; echo -e; break;;

        esac

    done

    if [ ! -z $container ]; then break; fi

done

if [ ! -z $container ] &&  [ $container  != "" ]; then 

    docker exec -it $container bash

else

    echo "Container not defined."

fi
