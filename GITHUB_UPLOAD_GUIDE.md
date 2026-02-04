# 🚀 ColdTrack GitHub Upload Guide

Complete guide to upload your ColdTrack project to GitHub.

---

## Step 1: Prepare Local Project

### Download Project Files

The complete ColdTrack project structure is ready in the `ColdTrack/` directory.

### Open VS Code

```bash
# Navigate to project
cd ColdTrack

# Open in VS Code
code .
```

---

## Step 2: Initialize Git Repository (Locally)

```bash
# Initialize git
git init

# Add all files
git add .

# First commit
git commit -m "Initial commit: ColdTrack IoT cold chain monitoring system

- Device simulator with MQTT connectivity
- AWS IoT Core integration
- Lambda data processor
- InfluxDB time-series storage
- Grafana visualization dashboards
- Automated setup scripts
- Comprehensive documentation
- Testing framework

Project structure complete and ready for development."
```

---

## Step 3: Connect to GitHub Repository

### Using Existing Repository

Your repository already exists: `Cold_Chain_Monitoring_System`

```bash
# Add remote
git remote add origin https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git

# Verify remote
git remote -v
```

### If Starting Fresh

```bash
# Create new repository on GitHub first
# Then:
git remote add origin https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git
```

---

## Step 4: Push to GitHub

### First Push

```bash
# Push to main branch
git push -u origin main
```

If you get an error about existing content:

```bash
# Option 1: Force push (if you want to overwrite)
git push -u origin main --force

# Option 2: Pull first, then push
git pull origin main --allow-unrelated-histories
git push -u origin main
```

---

## Step 5: Verify Upload

### Check on GitHub

1. Visit: https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System
2. You should see:
   - ✅ Complete directory structure
   - ✅ README.md displayed
   - ✅ All files uploaded
   - ✅ .gitignore working (certificates not uploaded)

### Expected Structure on GitHub

```
Cold_Chain_Monitoring_System/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── cloud/
│   ├── iot/
│   │   └── policies/
│   └── lambda/
│       ├── data_processor/
│       ├── alert_handler/
│       └── freeze_scorer/
├── config/
│   ├── docker-compose.yml
│   └── .env.example
├── device/
│   └── simulator/
│       ├── simulator.py
│       ├── config.json
│       └── requirements.txt
├── docs/
│   ├── architecture.md
│   ├── deployment_guide.md
│   ├── troubleshooting.md
│   └── quick_reference.md
├── scripts/
│   ├── setup_aws.sh
│   ├── deploy_lambda.sh
│   └── test_connection.sh
├── tests/
│   ├── unit/
│   └── integration/
├── visualization/
│   └── dashboards/
├── .gitignore
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── requirements.txt
```

---

## Step 6: Update Repository Settings

### 1. Add Description

On GitHub:
- Go to repository settings
- Add description: "IoT-enabled RSV vaccine cold chain monitoring system with real-time alerts and multi-dimensional freeze damage assessment"

### 2. Add Topics

Add topics/tags:
- `iot`
- `aws-iot-core`
- `cold-chain`
- `vaccine-monitoring`
- `influxdb`
- `grafana`
- `esp32`
- `mqtt`

### 3. Set Default Branch

- Ensure `main` is the default branch

### 4. Enable GitHub Actions

- Go to Actions tab
- Enable workflows
- Your CI/CD pipeline will run automatically

---

## Step 7: Create Initial Release (Optional)

### Tag First Release

```bash
# Create version tag
git tag -a v0.1.0 -m "Initial release: Core infrastructure complete

Features:
- Device simulator
- AWS IoT Core integration
- Lambda data processor
- InfluxDB storage
- Grafana dashboards
- Automated deployment scripts"

# Push tag
git push origin v0.1.0
```

### Create Release on GitHub

1. Go to "Releases" tab
2. Click "Create a new release"
3. Choose tag: v0.1.0
4. Release title: "ColdTrack v0.1.0 - Core Infrastructure"
5. Add release notes
6. Publish release

---

## Step 8: Collaborate with Team

### Invite Team Members

1. Go to Settings → Collaborators
2. Add team members:
   - Paul
   - Louis
   - Kevin

### Set Up Branch Protection (Optional)

1. Go to Settings → Branches
2. Add rule for `main` branch:
   - ✅ Require pull request reviews
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date

---

## Step 9: Next Steps for Development

### Clone on Team Members' Machines

```bash
# Each team member runs:
git clone https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git
cd Cold_Chain_Monitoring_System

# Setup their environment
pip install -r requirements.txt
cp config/.env.example .env
# Edit .env with their credentials
```

### Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes
# ... code ...

# 3. Commit changes
git add .
git commit -m "feat: description of changes"

# 4. Push branch
git push origin feature/your-feature

# 5. Create Pull Request on GitHub

# 6. After review and approval, merge
```

---

## Troubleshooting Upload Issues

### Issue: "Repository not found"

**Solution:**
```bash
# Verify remote URL
git remote -v

# Update if needed
git remote set-url origin https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git
```

### Issue: "Permission denied"

**Solution:**
```bash
# Set up SSH key (recommended)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitHub: Settings → SSH Keys
cat ~/.ssh/id_ed25519.pub

# Update remote to use SSH
git remote set-url origin git@github.com:Adhish-Rao2405/Cold_Chain_Monitoring_System.git
```

### Issue: "Large files rejected"

**Solution:**
```bash
# Remove large files from git history
git filter-branch --tree-filter 'rm -rf path/to/large/file' HEAD

# Or use .gitignore to prevent tracking
echo "large_file.zip" >> .gitignore
```

### Issue: ".env file uploaded accidentally"

**Solution:**
```bash
# Remove from git (keeps local copy)
git rm --cached .env

# Ensure it's in .gitignore
echo ".env" >> .gitignore

# Commit
git commit -m "fix: Remove .env from version control"
git push
```

---

## Important Security Notes

### Files That Should NEVER be Committed

✅ Already in .gitignore:
- `certificates/*.crt`
- `certificates/*.key`
- `certificates/*.pem`
- `.env`
- `*.log`

### What TO Commit

✅ Safe to commit:
- `.env.example` (template with placeholders)
- `config.json` (with placeholder endpoint)
- All Python code
- Documentation
- Scripts
- Test files

---

## Quick Command Reference

### Daily Operations

```bash
# Pull latest changes
git pull origin main

# Create feature branch
git checkout -b feature/new-feature

# Stage changes
git add .

# Commit
git commit -m "feat: description"

# Push branch
git push origin feature/new-feature

# Switch to main
git checkout main

# Merge feature (after PR approval)
git merge feature/new-feature
```

### Check Status

```bash
# View status
git status

# View commit history
git log --oneline

# View remote info
git remote -v

# View branches
git branch -a
```

---

## Success Checklist

After upload, verify:

- [ ] All files visible on GitHub
- [ ] README.md displays correctly
- [ ] No sensitive files committed (.env, certificates)
- [ ] .gitignore working properly
- [ ] GitHub Actions workflow present
- [ ] Documentation accessible
- [ ] Team members can clone
- [ ] Repository has description and topics

---

## Getting Help

**Git Issues:**
- [GitHub Docs](https://docs.github.com/)
- [Git Documentation](https://git-scm.com/doc)

**Project Issues:**
- Create issue on GitHub
- Check documentation in `docs/`
- Contact team members

---

**Ready to upload! 🎉**

Your complete ColdTrack project structure is ready for GitHub. Just follow the steps above and you'll have a professional, well-organized repository for your MSc capstone project.
