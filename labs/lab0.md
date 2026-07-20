# DevSecOps Labs — Setup and Lab 00 Guide

This guide explains how to prepare a Windows workstation for the DevSecOps labs and complete **Lab 00**.

> **Recommended environment**
>
> - Windows 10/11
> - WSL 2
> - Ubuntu running inside WSL
> - Docker Desktop integrated with Ubuntu WSL
> - Git 2.34 or later

---

## 1. Lab Environment Setup

### 1.1 Create a GitHub account

Create a personal account at GitHub.

You will use this account to:

- Create your own public lab repository.
- Create branches.
- Push lab submissions.
- Open and merge pull requests.
- Run GitHub Actions workflows.

After creating the account, verify that you can sign in successfully.

---

### 1.2 Create a Docker Hub account

Create a personal Docker Hub account.

Docker Hub may be used in later labs to:

- Pull public container images.
- Push your own container images.
- Authenticate from CI/CD pipelines.
DevSecOps-lab-26
After creating the account, verify that you can sign in successfully.

---

### 1.3 Install WSL on Windows

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

Restart Windows if requested.

---

### 1.4 Install Ubuntu in WSL

List available Linux distributions:

```powershell
wsl --list --online
```

Install Ubuntu:

```powershell
wsl --install -d Ubuntu-24.04
```

Start Ubuntu:

```powershell
wsl -d Ubuntu-24.04
```

During the first startup, create a Linux username and password.

Update the Ubuntu package list:

```bash
sudo apt update
sudo apt upgrade -y
```

---

### 1.5 Install Docker Desktop

Download and install Docker Desktop for Windows.

During installation, use the WSL 2 backend when prompted.

After installation:

1. Start Docker Desktop.
2. Open **Settings**.
3. Open **General**.
4. Enable **Use the WSL 2 based engine**.
5. Open **Resources > WSL Integration**.
6. Enable integration for your Ubuntu distribution.
7. Select **Apply & Restart**.

---

### 1.6 Integrate Docker Desktop with Ubuntu WSL

Open Ubuntu WSL and verify Docker:

```bash
docker --version
docker ps
```

If you receive a Docker socket permission error such as:

```text
permission denied while trying to connect to the Docker daemon socket
```

add your current Linux user to the `docker` group:

```bash
sudo usermod -aG docker $USER
```

Exit Ubuntu:

```bash
exit
```

Open **PowerShell** and fully stop WSL:

```powershell
wsl --shutdown
```

Start Ubuntu again:

```powershell
wsl -d Ubuntu-24.04
```

Verify that your user belongs to the `docker` group:

```bash
groups
```

Expected output should include:

```text
docker
```

Test Docker again:

```bash
docker ps
```

Run a test container:

```bash
docker run --rm hello-world
```

> Do not use `sudo docker ...` as the normal solution. Adding the user to the `docker` group allows Docker commands to run without `sudo`.

---

### 1.7 Install Git 2.34 or later

Inside Ubuntu WSL, install Git:

```bash
sudo apt update
sudo apt install -y git
```

Verify the version:

```bash
git --version
```

The version should be **2.34 or later**.

Configure your Git identity:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

Verify the configuration:

```bash
git config --global --list
```

---

### 1.8 Install `curl` and `jq`

Inside Ubuntu WSL, run:

```bash
sudo apt update
sudo apt install -y curl jq
```

Verify both tools:

```bash
curl --version
jq --version
```

#### What these tools are used for

- `curl` sends HTTP requests and downloads data from URLs or APIs.
- `jq` reads, filters, and formats JSON output.

Example:

```bash
curl -s https://api.github.com/repos/golden-P11/DevSecOps-lab-26 | jq '.name, .visibility'
```

> On Ubuntu WSL, use `apt`. The command `brew install jq` is intended for systems that already have Homebrew installed.

---

## 2. Lab 00 — Git and Pull Request Workflow

### 2.1 Objective

In Lab 00, you will:

1. Download the lab repository for reference.
2. Create your own public GitHub repository.
3. Create a feature branch.
4. add only the required lab submission file.
5. Push the feature branch.
6. Open a pull request.
7. Merge the pull request into `main`.

---

### 2.2 Clone the lab repository

Inside Ubuntu WSL, clone the source repository:

```bash
git clone https://github.com/golden-P11/DevSecOps-lab-26.git
```

Enter the repository:

```bash
cd DevSecOps-lab-26
```

To retrieve future changes:

```bash
git pull origin main
```

---

### 2.3 Repository structure

The lab repository has a structure similar to:

```text
DevSecOps-lab-26/
├── .github/
│   ├── workflows/
│   │   └── lab1-smoke.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── labs/
│   ├── lab1.md
│   └── labxx.md
└── submissions/
    └── lab1.md
```

Directory purposes:

| Path | Purpose |
|---|---|
| `.github/workflows/` | GitHub Actions workflow files |
| `.github/PULL_REQUEST_TEMPLATE.md` | Default pull request template |
| `labs/` | Lab instructions |
| `submissions/` | Student lab answers or evidence |

---

### 2.4 Create a personal public repository

On GitHub:

1. Select **New repository**.
2. Enter a repository name, for example:

   ```text
   devsecops-lab-submissions
   ```

3. Select **Public**.
4. Do not initialize it with a README, `.gitignore`, or license.
5. Select **Create repository**.

Copy the HTTPS URL, for example:

```text
https://github.com/YOUR-USERNAME/devsecops-lab-submissions.git
```

---

## 3. Important Rule: Do Not Push the Entire Source Repository

Git pushes commits and repository history, not isolated files.

If you clone the original lab repository, change its remote, and push it directly, you may also push:

- The original commit history.
- Existing files.
- Original contributor information.
- Workflow files that were not part of your submission.

The source repository is used for reading instructions and doing exercises.

The submissions sub folder contains only the files that you are required to submit.

---

## 4. Task 1 — Submit Lab 00 Through a Pull Request

### 4.1 Configure remote Repo

Return to the parent directory:

```bash
cd DevSecOps-lab-26
```

Initialize Git:

```bash
git init
```

Connect it to your personal GitHub repository:

```bash
git remote add origin https://github.com/YOUR-USERNAME/devsecops-lab-submissions.git
```

Verify the remote:

```bash
git remote -v
```

---

### 4.2 Create the initial `main` branch

Create a README:

```bash
cat > README.md <<'EOF'
# DevSecOps Lab Submissions

This repository contains my DevSecOps lab submissions.
EOF
```

Commit the file:

```bash
git add README.md
git commit -m "Initialize lab submission repository"
```

Push the `main` branch:

```bash
git push -u origin main
```

When GitHub asks for authentication:

- Username: your GitHub username.
- Password: use a GitHub Personal Access Token (PAT), not your GitHub password. Create your own PAT (Fine-grained): Contents (Read & Write); Workflows (Read & Write)

---

### 4.3 Create the feature branch

Create and switch to a new branch:

```bash
git switch -c feature/lab0
```

Alternative command:

```bash
git checkout -b feature/lab0
```

Verify the current branch:

```bash
git branch
```

Expected output:

```text
* feature/lab0
  main
```

---

### 4.4 Create the Lab 00 file

Create the file:

```bash
nano submissions/lab0.md
```

Example content:

```markdown
# Lab 00 Submission

## Environment

- Operating system: Windows with Ubuntu WSL 2
- Docker: Installed and integrated with Ubuntu WSL
- Git: Installed
- curl: Installed
- jq: Installed

## Verification

```bash
wsl -l -v
docker --version
docker ps
git --version
curl --version
jq --version
```

## Result

The DevSecOps lab environment was prepared successfully.
```

Save the file in Nano:

```text
Ctrl + O
Enter
Ctrl + X
```

---

### 4.5 Check changed files

Run:

```bash
git status
```

Expected result:

```text
Untracked files:
  submissions/lab0.md
```

Only add the required submission file:

```bash
git add submissions/lab0.md
```

DO NOT use the following command unless you intentionally want to add every changed file: "git add ."


Verify the staged file:

```bash
git status
```

You should see only:

```text
new file: submissions/lab0.md
```

---

### 4.6 Commit the Lab 00 file

Create the commit:

```bash
git commit -m "Add Lab 00 submission"
```

Review the commit:

```bash
git show --stat --oneline HEAD
```

Verify that the commit contains only the intended file:

```bash
git diff HEAD~1 --name-only
```

Expected output:

```text
submissions/lab0.md
```

---

### 4.7 Push the feature branch

Push the branch:

```bash
git push -u origin feature/lab0
```

The `-u` option connects the local branch to the remote branch. Future pushes can use:

```bash
git push
```

---

### 4.8 Create a pull request

On GitHub:

1. Open your personal repository.
2. Select **Compare & pull request**.
3. Confirm:

   ```text
   base: main
   compare: feature/lab0
   ```

4. Enter a title:

   ```text
   Lab 00 Submission
   ```

5. Review the **Files changed** tab.
6. Confirm that only `labs/lab0.md` is included.
7. Select **Create pull request**.

---

### 4.9 Merge the pull request

After reviewing the pull request:

1. Select **Merge pull request**.
2. Select **Confirm merge**.
3. Optionally delete the remote feature branch.

Update the local `main` branch:

```bash
git switch main
git pull origin main
```

---

## 5. Workflow for Future Labs

For each new lab, use a separate branch and submission file.

Example for Lab 1:

```bash
git switch main
git pull origin main
git switch -c feature/lab1

nano submissions/lab1.md

git add submissions/lab1.md
git commit -m "Add Lab 1 submission"
git push -u origin feature/lab1
```

Then create and merge a pull request from:

```text
feature/lab1 -> main
```

Recommended naming convention:

| Lab | Branch | Submission file |
|---|---|---|
| Lab 00 | `feature/lab0` | `submissions/lab0.md` |
| Lab 1 | `feature/lab1` | `submissions/lab1.md` |
| Lab 2 | `feature/lab2` | `submissions/lab2.md` |
| Lab 3 | `feature/lab3` | `submissions/lab3.md` |

---

## 6. Final Verification Checklist

### Environment

- [ ] GitHub account created.
- [ ] Docker Hub account created.
- [ ] WSL 2 installed.
- [ ] Ubuntu installed in WSL.
- [ ] Docker Desktop installed.
- [ ] Docker Desktop integrated with Ubuntu WSL.
- [ ] Current Linux user belongs to the `docker` group.
- [ ] `docker ps` works without `sudo`.
- [ ] Git 2.34 or later installed.
- [ ] `curl` installed.
- [ ] `jq` installed.

### Lab 00

- [ ] Source lab repository cloned locally.
- [ ] Personal public GitHub repository created.
- [ ] Separate local submission repository initialized.
- [ ] Branch `feature/lab0` created.
- [ ] Only `labs/lab0.md` added to the Lab 00 commit.
- [ ] Feature branch pushed to GitHub.
- [ ] Pull request created.
- [ ] Pull request reviewed.
- [ ] Pull request merged into `main`.

---

## 7. Useful Commands

```bash
# Show the current branch
git branch --show-current

# Show repository status
git status

# Show configured remotes
git remote -v

# Show compact commit history
git log --oneline --graph --decorate --all

# Show files in the latest commit
git show --name-only --oneline HEAD

# Show differences before committing
git diff

# Show staged differences
git diff --staged

# Verify Docker access
docker ps

# Verify Linux groups
groups
```
