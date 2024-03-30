#!/bin/bash


# Global variable to save the name of the file that have been passed as argument by the use.
file=$1


################################## Main Menu ##################################
################################## User Interface ##################################


Menu(){
    # local chosenAction
    # local inputString
    # local inputAmount
    # local chosenEntry
    CheckFile
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


################################## Main Menu Functions ##################################


# Adds a new record to the DB if it doesn't exist, updates the amount if it already exists.
Insert(){
    local name=""
    local amount=0
    local selected_record=""
    local status=0
    
    while [[ $status -eq 0 ]]; do
        echo "[!] What would you like to do?"
        echo "1) Add new record."
        echo "2) Add copies to existing record."
        read -p "[!] Enter your choice number: " num

        if [[ $num -eq 1 ]]; then
            name=$(name_validate)
            amount=$(amount_validate)
            find_line=$(grep -w "^$name," "$file")

            while [ -n "$find_line" ]; do 
                echo "[!] A record with the same name already exists."
                name=$(name_validate)
                find_line=$(grep -w "^$name," "$file")
            done

            echo "$name, $amount" >> $file
            echo "[!] A new record has been added."
            log_event $FUNCNAME Success
            status=1

        elif [[ $num -eq 2 ]]; then
            name=$(name_validate)
            amount=$(amount_validate)
            ListRecords "$name" selected_record

            local old_amount=$(echo "$selected_record" | awk -F', ' '{print $2}')
            local new_amount=$((old_amount + amount))
            local new_record=$(echo "$selected_record" | awk -F', ' '{print $1}')

            # Use a safe sed replacement with variables.
            sed -i "s/^$selected_record\$/$new_record, $new_amount/" $file

            echo "[!] Copies added successfully to $new_record, total is now $new_amount."
            log_event $FUNCNAME Success
            status=1

        else
            echo "[!] Invalid option. Please choose one from the list."
            log_event $FUNCNAME Failure
        fi
    done

    Menu
}



# Searches for a record by name (Or part of it), returns a list of all the records that contain the name provided.
Delete() {
    local term=$(name_validate)
    local amount=$(amount_validate)    # Amount to delete.
    local full_record
    local curr_name=""
    local curr_amount=""
    local check=1 # Incorrect, enters while loop.

    ListRecords "$term" full_record
    curr_name=$(echo "$full_record" | awk -F', ' '{print $1}')
    curr_amount=$(echo "$full_record" | awk -F', ' '{print $2}')

    echo "[!] You have selected $curr_name with $curr_amount copies"

    while [ $check -eq 1 ]; do # Runs as long as the input is incorrect.
        # Check if choice is validate.
        if [[ $amount -le $curr_amount ]]; then
            check=0  # Correct, exits while loop.
            # Subtracting amount of copies.
            let new_amount=($curr_amount - $amount)
            if [[ "$new_amount" -gt 0 ]]; then
                # Use a different delimiter and properly quote variables.
                sed -i "s|$curr_name, $curr_amount|$curr_name, $new_amount|g" $file
                echo "[!] The new copies amount of $curr_name is $new_amount"
                log_event $FUNCNAME Success
            else [[ "$new_amount" -eq 0 ]]
                sed -i "/^$curr_name, $curr_amount$/d" $file
                echo "[!] You have deleted all the copies of $curr_name"
                log_event $FUNCNAME Success
            fi
        else
            echo "[!] Cannot delete more copies than we already have."
            check=1
            log_event $FUNCNAME Failure
            echo "[!] How many copies would you like to delete? - Max is $curr_amount"
            amount=$(amount_validate)
        fi
    done
    Menu
}
  

# Searches for a record by name (Or part of it), returns a list of all the records that contain the name provided.
Search(){
    local name=$(name_validate)

    # Perform case-insensitive search and format output
    local results=$(grep -i "$name" "$file" | sort | awk -F', ' '{print NR") "$1", "$2}')

    # Check if any results were found
    if [[ -z "$results" ]]; then
        echo "[!] No records found containing '$name'."
        log_event $FUNCNAME Failure
    else
        # Print formatted results
        echo "$results"
        log_event $FUNCNAME Success
    fi

  Menu
}


# Updates a record name, provided by the user.
UpdateName(){
    local name=""
    local full_record=""
    local search_term=$(name_validate)
    ListRecords "$search_term" full_record
    local is_new=1
    local line_search=""
    local curr_name=$(echo "$full_record" | awk -F', ' '{print $1}')
    local curr_amount=$(echo "$full_record" | awk -F', ' '{print $2}')
    while [[ $is_new -eq 1 ]]; do
        name=$(name_validate)
        is_new=0
        line_search=$(grep -w "$name" "$file")
        if [[ ! -z $line_search ]]; then
            echo "[!] A record with that name already exists. Please choose a different name."
            is_new=1
        fi
    done

    local temp_file=$(mktemp)
    while IFS= read -r line; do
        local line_name=$(echo "$line" | awk -F', ' '{print $1}')
        if [[ "$line_name" == "$curr_name" ]]; then
            echo "$name, $curr_amount" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file"

    mv "$temp_file" "$file" # Replace the original file with the temp file

    if [[ $? -eq 0 ]]; then
        log_event $FUNCNAME Success
    else
        log_event $FUNCNAME Failure
    fi
    Menu
}


# Updates the copies amount of a certain record, provided by the use.
UpdateAmount() {
    local search_term=$(name_validate)  # User inputs the search term for the record.
    local new_amount=$(amount_validate)  # User inputs the new amount.
    local full_record=""
    
    # ListRecords to let the user select a record based on the search term.
    ListRecords "$search_term" full_record  
    
    if [[ -z "$full_record" ]]; then
        echo "Operation cancelled or no matching records found."
        return
    fi

    # Extract the current name and amount from the selected record.
    local curr_name=$(echo "$full_record" | awk -F', ' '{print $1}')
    local curr_amount=$(echo "$full_record" | awk -F', ' '{print $2}')
    
    # Replace the old amount with the new amount while keeping the name unchanged.
    if sed -i "/^$curr_name, $curr_amount$/s/$curr_amount/$new_amount/" "$file"; then
        echo "[!] The amount for '$curr_name' has been updated successfully to $new_amount."
        log_event $FUNCNAME Success 
    else
        echo "Failed to update the amount for '$curr_name'."
        log_event $FUNCNAME Failure
    fi
    Menu
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
    Menu
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
    Menu
}


################################## Helping Methods ##################################


# Checks if the DB file already exists, if not, ask the user if he wants to proceed and create one.
CheckFile (){
    if ! [ -f $file ]; then
        read -p '[!] File does not exist! Do you want to proceed tp create it?[y/n]' answer
        answer=$( echo $answer | tr '[:upper:]' '[:lower:]')
        case $answer in
            yes | y)
                touch $file
                echo "[!] file created successfully!";;
            no | n)
                echo file wasnt created! thank you and good-bye
                exit 0 ;;
            *)
                echo "[!] not valid input, please try again."
                exit 0 ;;
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') -" $fun $status1 $status2 >> "$file"_log.txt
    status2=""
}


# Lists all the records to the user that contain a certain word of a record name, provide by the user.
ListRecords(){
    local final_result=""
    local search_term=$1
    local return_val=$2
    local search_result=""
    local results_array=()
    local num=0
    local counter=1
    local status=1
    local num_check='^[0-9]+$'

    # While loop until the user chooses the correct option
    status=1
    local read_status=1
    while [[ $status -eq 1 ]]; do
    # Read file line by line using grep and add all the results to the array
        while [[ $read_status -eq 1 ]]; do
            search_result=$(grep -i "$search_term" "$file")
            IFS=$'\n' read -r -d '' -a results_array <<< "$search_result"
            read_status=0  # Finished reading file, exiting while
        done 
        counter=1
        num=0
        if [[ ${#results_array[@]} -eq 1 ]]; then   # Checking if only one value in array
            echo "[!] Result found: ${results_array[0]}"
            num=0 
            status=0 # Exits while loop
        elif  [[ ${#results_array[@]} -eq 0 ]]; then  # Checking if no values in array
            echo "No matching results"
            search_term=$(name_validate)
        else
            for value in "${results_array[@]}"; do
                echo "$counter) $value"
                let "counter=($counter+1)"
            done
            let "counter=($counter-1)"
            read -rp "[!] Please choose an option: " num      
            if [[ $num =~ $num_check ]] && [[ $num -le $counter ]] && [[ $num -gt 0 ]]; then
                let num=$num-1
                status=0
            else
                echo "[!] Invalid option. Please choose one from the list."
            fi
        fi
    done
    final_result="${results_array[$num]}"
    eval $return_val="'$final_result'"
}

Menu