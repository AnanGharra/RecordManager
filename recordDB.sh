#!/bin/bash

# Global variable that holds the data base file path.
file=$1



############################################################# MENU INTERFACE #############################################################



# Lists the menu interface of the Record Manager for the user.
menu(){
    # local action name amount entry
    file_check
    local file_update=""
    file_update=$(cat $file)

    echo "Welcome to Record Manager!"
    echo "What would you like to do?"
    select option in "Insert a record." "Delete a record." "Search for a record." "Update a record name." "Update a record's copies amount." "Print total copies amount." "Print all records." "Exit."
    do
        case $option in
            1|"Insert a record.") 
                echo "[!] Inserting a record..."
                Insert;;
            2|"Delete a record.")
                echo "[!] Deleting a record..."
                Delete;;
            3|"Search for a record.")
                echo "[!] Searching for a record..."
                Search;;
            4|"Update a record name.")
                echo "[!] Updating a record name..."
                UpdateName;;
            5|"Update a record's copies amount.") 
                echo "[!] Updating copies amount..."
                UpdateAmount;;
            6|"Print total copies amount.")
                echo "[!] Printing all the copies amount..."
                PrintAmount;;
            7|"Print all records.") 
                echo "[!] Printing all the records..."
                PrintAll;;
            8|"Exit.")
                echo "[!] Exiting the Record Manager..."
                exit;;
            *)
                echo "[!] This option is not available yet! Please choose one from the menu.";;
        esac
    done
}



############################################################# MENU FUNCTIONS #############################################################



# Adds a new record to the DB if it doesn't exist, updates the amount if it already exists
Insert(){
    local name=0
    local amount=0
    local option=""
    local num=0
    local status=0

    while [[ $status -eq 0 ]]; do
        echo "[!] What would you like to do?"
        echo "1) Add a new record."
        echo "2) Add copies to existing record."
        read -p "[!] Enter you choice number: " num

        if [[ $num -eq 1 ]]; then
            name=$(name_validate)
            amount=$(amount_validate)

            result=`grep ^"$name" "$file"`
            while [ -n "$result" ]; do
                echo "[!] A record with the same name already exists."
                name=$(name_validate)
                result=`grep ^"$name" "$file"`
            done

            log_event $FUNCNAME Success
            echo "$name, $amount" >> $file
            echo "[!] A new record has been added."
            status=1
        elif [[ $num -eq 2 ]]; then
            name=$(name_validate)
            amount=$(amount_validate)
            list_records $name option

            declare old_amount=`echo "$option" | awk -F', ' '{print $2}'`
            let amount_to_add=$amount
            declare new_amount=$((old_amount+amount_to_add))
            curr_name=`echo "$option" | awk -F', ' '{print $1}'`
            new_record=`echo $curr_name, $new_amount`

            sed -i "s/$option/$new_record/g" $file
            echo "[!] Record Added Successfully"
            log_event $FUNCNAME Success
            status=1
        else
            echo "[!] Invalid Option! Please choose and option from the list."
            status=0
            log_event $FUNCNAME Failure
        fi
    done
    menu
}


# Deletes a record, or some copies from it.
Delete(){
    local name=$(name_validate)
    local amount=$(amount_validate)
    local full_name
    local curr_name=""
    local curr_amount=""
    local check=1
    list_records $name full_name
    curr_name=$(echo $full_name | awk -F', ' '{print $1}')
    curr_amount=$(echo $full_name | awk -F', ' '{print $2}')

    while [ $check -eq 1 ]; do
        if [[ $amount -le $curr_amount ]]; then
            check=1
            let new_amount=($curr_amount - $amount)
            echo $new_amount
            if [[ $new_amount -gt 0 ]]; then
                sed -i "s/$full_name/$curr_name, $new_amount/g" $file
                echo "[!] The new copies amount of $curr_name has been updated to $new_amount."
                check=0
                log_event $FUNCNAME Success
            else [[ "$new_amount" -eq 0 ]]
                sed -i "s/$full_name/d" $file
                echo "[!] All the copies of $full_name has been deleted."
                log_event $FUNCNAME  Success
            fi
        else
            echo "[!] Can't delete more copies than we already have."
            check=1
            log_event $FUNCNAME Failure
            echo "[!] The copies amount of $full_name is $curr_amount, How many would you like to delete?"
            amount=$(amount_validate $option)
        fi
    done
    menu
}


# Searches for a record by name (Or part of it), returns a list of all the records that contain the name provided.
Search(){
    local name=$(name_validate)
    local results_array=()
    # local results_sorted=()
    local search_results=""
    local sorted=""

    search_results=$(grep "$name" "$file")
    if [ -n "$search_results" ]; then
        sorted=$(echo $search_results | tr ' ' '\n' | sort)
        for i in $sorted; do
            results_array+=("$i")
        done
        log_event $FUNCNAME Success
    else
        echo "[!] Record Not Found."
        log_event $FUNCNAME Failure
    fi

    for record in "${results_array[@]}"; do
        echo "$record"
    done

    menu
}


# Updates a record name, provided by the user.
UpdateName(){
    local name=""
    local full_name=""
    local search_term=$(name_validate)
    list_records $search_term $full_name
    local is_new=1
    local line=""
    local curr_name=$(echo $full_name | awk -F', ' '{print $1}')
    local curr_amount=$(echo $full_name | awk -F', ' '{print $2}')
    while [[ $in_new -eq 1 ]]; do
        name=$(name_validate)
        is_new=0
        local line=`grep -w $name $file`
        if [[ -z $line ]]; then
            echo "[!] A record with that name already exists."
            is_new=1
        fi
    done
    if sed -i "s/$curr_name/$name/g" "$file"; then
        log_event $FUNCNAME Success
    else
        log_event $FUNCNAME Failure
    fi

    menu
}


 
# Prints all the copies amount in the DB
PrintAmount(){
    local all_records=$(sort $file)
    local counter=0
    if [ -s $file ]; then
        while IFS= read -r record; do
            local curr_amount=$(echo $record | awk -F', ' '{print $2}')
            counter=$((counter + curr_amount))
        done <<< "$all_records"
        echo "[!] The total amount of copies is: $counter"
        log_event $FUNCNAME $counter
    else
        echo "[!] That databse is empty."
        log_event $FUNCNAME Failure
    fi
    menu
}

# Prints all the records in the DB in a sorted way.
PrintAll(){
    local all_records=$(sort $file)
    if [ -s $file ]; then
        while IFS= read -r record; do
            local curr_record=$(echo $record | awk -F', ' '{print $1}')
            local curr_amount=$(echo $record | awk -F', ' '{print $2}')
            echo "$curr_record, $curr_amount"
            log_event $FUNCNAME "$curr_record" "$curr_amount"
        done <<< "$all_records"
    else
        echo "[!] The database is empty."
        log_event $FUNCNAME Failure 
    fi
    menu
}



############################################################# HELPERS FUNCTIONS #############################################################



# Checks if the DB file already exists, if not, ask the user if he wants to proceed and create one.
file_check(){
    if ! [ -f $file ]; then
        read -p "[!] The current file does not exist. Do you wish to create it?[y/n]" ans
        ans=$(echo $ans | tr '[:upper:]' '[:lower:]')
        case $ans in
            yes|y)
                touch $file;;
            no|n) 
                echo "[!] The file was not created. Thank you... :)"
                exit;;
            *)
                echo "[!] Invalid option. Please enter y for yes and n for no"
                exit;;
        esac
    fi
}

# Asks the user to enter a record name and validates it.
name_validate(){
    local reg='^[a-zA-Z0-9\ ]+$'
    local name
    local input_check=1
    local message="[!] Please enter a record name: "
    while [ $input_check -eq 1 ]; do
        read -p "$message" name
        input_check=0
        if ! [[ $name =~ $reg ]]; then
            input_check=1
            message="[!] Invalid Name! Please use only letters, numbers and spaces."
        fi
    done
    echo $name
}


# Asks the user in enter the copies amount and validates it - positive, greater than 0.
amount_validate(){
    local reg='^[0-9]+$'
    local amount
    local input_check=1
    local message="[!] Please enter the record's copies amount: "
    while [ $input_check -eq 1 ]; do
        read -p "$message" amount
        input_check=0
        if ! [[ $amount =~ $reg ]] && ! [ $amount -gt 0]; then
            input_check=1
            message="[!] Invalid Amount! Please use only positive numbers with no spaces and greater than 0."
        fi
    done
    echo $amount
}


# LOG
log_event(){
    local fun=$1
    local status1=$2
    local status2=$3
    echo "$(date '+%Y-%m-%d %H:%M:%S') - " $fun $status1 $status2 >> "$file"_log.txt
    status2=""
}


# Searches for the record name in the DB, and returns all the records that contain the name provided as a numbered list.
list_records(){
    local final_result=""
    local search_term=$1
    local return_val=$2
    local search_result=""
    local results_array=()
    local num=0
    local counter=1
    local status=1
    local reg='^[0-9]+$'
    local i=""
    local file_read=1
    while [[ $status -eq 1 ]]; do
        while [[ $file_read -eq 1 ]]; do
            search_results=$(grep -i "$search_term" "$file")
            while IFS= read -r line; do
                results_array+=("$line")
            done < <(grep -i "$search_term" "$file")
            file_read=0
        done
        counter=1 
        num=0
        # printf "%s\n" "${results_array[@]}"

        if [[ ${#results_array[@]} -eq 1 ]]; then
            echo "[!] Results Found: "
            echo "${results_array[0]}"
            status=0
            num=0
            # log_event $FUNCNAME Success
        elif [[ ${#results_array[@]} -eq 0 ]]; then
            echo "[!] No Records Found."
            search_term=$(name_validate)
        else
            for record in "${results_array[@]}"; do
                echo "$counter) $record"
                let counter=($counter+1)
            done
            let counter=($counter+1)
            read -rp "[!] Please enter the record number from the list: " num
            if [[ $num =~ $reg ]] && [[ $num -lt $counter ]] && [[ $num -gt 0 ]]; then
                let num=$num-1
                # log_event $FUNCNAME Success
                status=0
            else
                echo "[!] Invalid option. Please choose a record number from the list."
                # log $FUNCNAME Failure
            fi
        fi
    done
    final_result="${results_array[$num]}"
    # eval $return_val="'$final_result'"
    echo "$final_results"
}


menu







