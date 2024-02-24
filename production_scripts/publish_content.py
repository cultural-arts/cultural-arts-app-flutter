import os
import paramiko
import pathlib
from tqdm import tqdm  # Import the tqdm library
import argparse
import subprocess

def get_password():
    return input("Enter your password: ")

def create_remote_directory(sftp, remote_dir):
    try:
        sftp.stat(remote_dir)
    except FileNotFoundError:
        # Directory doesn't exist, so create it
        sftp.mkdir(remote_dir)

def create_remote_directory_recursive(sftp, remote_base, local_base):
    list_dirs = list(local_base.parts)
    for idx, _ in enumerate(list_dirs):
        target_dir = '/'.join([d for d in list_dirs[:idx+1]])
        remote_dir = pathlib.Path(os.path.join(remote_base, target_dir)).as_posix()
        create_remote_directory(sftp, remote_dir)

def copy_files_to_remote(remote_user, remote_host, local_build, remote_build, password):
    print('Copying files to the remote server...')
    
    # Set up SSH transport
    transport = paramiko.Transport((remote_host, 22))
    transport.connect(username=remote_user, password=password)  # or use key-based authentication
    
    # Initialize SFTP client
    sftp = paramiko.SFTPClient.from_transport(transport)

    created_directories = []
    created_directories.append(remote_build)
    
    # Copy static files with a loading bar
    static_files = list(local_build.rglob('*'))
    with tqdm(total=len(static_files), unit='files') as pbar:
        for local_file_path in static_files:
            if local_file_path.is_file():  # Check if it's a file, not a directory
                remote_file_path = os.path.join(remote_build, local_file_path.relative_to(local_build))
                remote_file_path = os.path.normpath(remote_file_path)
                remote_file_path = remote_file_path.replace('\\', '/')  # Replace backslashes with forward slashes
                current_remote_dir = os.path.dirname(remote_file_path)
                if not current_remote_dir in created_directories:
                    try:
                        # Create directories recursively
                        rel_path = os.path.relpath(current_remote_dir, remote_build)
                        rel_path = pathlib.Path(rel_path)
                        create_remote_directory_recursive(sftp, remote_build, rel_path)
                    except Exception as e:
                        print(e)
                    finally:
                        created_directories.append(current_remote_dir)
                sftp.put(str(local_file_path), str(remote_file_path))
                pbar.update(1)
    
    # Close SFTP and transport
    sftp.close()
    transport.close()
    
    print('Files copied to the remote server.')

def modify_index_html(local_build):
    index_html_path = local_build / 'index.html'
    try:
        with open(index_html_path, 'r') as file:
            content = file.read()
        
        # Perform string replacements
        content = content.replace('href="/"', 'href="/bio-colonization/"')
        content = content.replace('href="favicon.png"', 'href="/bio-colonization/favicon.png"')
        content = content.replace('href="manifest.json"', 'href="/bio-colonization/manifest.json"')
        content = content.replace('src="flutter.js"', 'src="/bio-colonization/flutter.js"')
        
        # Write the modified content back to the file
        with open(index_html_path, 'w') as file:
            file.write(content)
    except FileNotFoundError:
        print("index.html file not found. Skipping modifications.")

def run_flutter_build(project_root):
    try:
        subprocess.run(['flutter', 'build', 'web'], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Flutter build failed with error: {e}")
        raise

def main():
    parser = argparse.ArgumentParser(description='Copy files to a remote server over SSH')
    parser.add_argument('--user', required=True, help='Remote user')
    parser.add_argument('--host', required=True, help='Remote host')
    parser.add_argument('--local_build', required=True, help='Path to local build directory')
    parser.add_argument('--remote_build', required=True, help='Path on the remote server for build files')
    parser.add_argument('--project_root', required=True, help='Project root')
    parser.add_argument('--password', help='Password for authentication')
    args = parser.parse_args()

    if not args.password:
        args.password = get_password()  # Prompt for password if not provided
    
    local_build = pathlib.Path(args.local_build)

    modify_index_html(local_build)
    
    copy_files_to_remote(args.user, args.host, local_build, args.remote_build, args.password)

if __name__ == '__main__':
    main()
