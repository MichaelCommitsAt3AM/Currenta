import re

auth_file = "/home/michael/AndroidStudioProjects/Currenta/scratch/auth_data.sql"
public_file = "/home/michael/AndroidStudioProjects/Currenta/scratch/public_user_data.sql"

filtered_auth_file = "/home/michael/AndroidStudioProjects/Currenta/scratch/filtered_auth_data.sql"
filtered_public_file = "/home/michael/AndroidStudioProjects/Currenta/scratch/filtered_public_user_data.sql"

# Regex for UUID
uuid_pattern = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")

# Step 1: Scan auth_data.sql to find all registered users
registered_user_ids = set()

with open(auth_file, "r", encoding="utf-8") as f:
    lines = f.readlines()

in_users_insert = False
for line in lines:
    if 'INSERT INTO "auth"."users"' in line:
        in_users_insert = True
        continue
    if in_users_insert:
        # Check if we reached the end of the block
        is_end = line.strip().endswith(";")
        
        # Parse user
        stripped = line.strip().rstrip(",;)")
        if stripped.endswith("false"): # is_anonymous = false
            uuids = uuid_pattern.findall(line)
            if len(uuids) >= 2:
                # The first UUID is instance_id, second is user_id
                user_id = uuids[1]
                registered_user_ids.add(user_id)
                print(f"Found registered user: {user_id}")
                
        if is_end:
            in_users_insert = False

print(f"Total registered users found: {len(registered_user_ids)}")

def filter_sql_file(input_path, output_path, registered_ids, allowed_tables=None):
    with open(input_path, "r", encoding="utf-8") as f:
        in_lines = f.readlines()
        
    out_lines = []
    
    # We will buffer values for each INSERT block to reconstruct them properly
    in_insert = False
    insert_header = ""
    value_rows = []
    skip_table = False
    
    for line in in_lines:
        if line.strip().startswith("INSERT INTO"):
            # If we were already in an insert block
            if in_insert and value_rows and not skip_table:
                write_reconstructed_insert(out_lines, insert_header, value_rows, registered_ids)
                
            # Determine if this table is allowed
            if allowed_tables is not None:
                skip_table = not any(f'"{t}"' in line or f'.{t}' in line for t in allowed_tables)
            else:
                skip_table = False
                
            in_insert = True
            insert_header = line
            value_rows = []
        elif in_insert:
            # We are inside an INSERT VALUES block
            is_end = line.strip().endswith(";")
            if not skip_table:
                value_rows.append(line)
            if is_end:
                if not skip_table and value_rows:
                    write_reconstructed_insert(out_lines, insert_header, value_rows, registered_ids)
                in_insert = False
                insert_header = ""
                value_rows = []
        else:
            # Regular non-insert lines (comments, set variables, etc.)
            out_lines.append(line)
            
    with open(output_path, "w", encoding="utf-8") as f:
        f.writelines(out_lines)

def write_reconstructed_insert(out_lines, header, rows, registered_ids):
    kept_rows = []
    for r in rows:
        # Clean up the row and check if it contains any of the registered user IDs
        uuids = uuid_pattern.findall(r)
        # Keep row if it contains at least one of the registered user IDs, OR if it has no UUIDs at all (system/static data)
        # Note: some rows might not have any UUID if they are static/lookup tables, but auth and public user tables always do.
        if any(uid in uuids for uid in registered_ids):
            kept_rows.append(r.strip().rstrip(",;"))
        elif not uuids:
            kept_rows.append(r.strip().rstrip(",;"))
            
    if kept_rows:
        out_lines.append(header)
        for i, row in enumerate(kept_rows):
            suffix = ";" if i == len(kept_rows) - 1 else ","
            out_lines.append(f"\t{row}{suffix}\n")
        out_lines.append("\n")

# Filter both files
print("Filtering auth_data.sql...")
filter_sql_file(auth_file, filtered_auth_file, registered_user_ids)
print("Filtering public_user_data.sql...")
filter_sql_file(public_file, filtered_public_file, registered_user_ids, allowed_tables=['user_profiles', 'user_interests', 'user_sub_interests', 'user_ai_usage'])
print("Filtering completed!")
