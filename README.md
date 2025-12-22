# Travel Site - Azure Functions App

A travel website with Azure Functions backend integration.

## Prerequisites

- Python 3.9 or later (3.11.x or 3.12.x recommended)
- Azure Functions Core Tools (version 4.x)
- Azure Storage Emulator or Azurite (for local development)

## Setup

1. **Create a virtual environment:**
   ```bash
   python -m venv .venv
   ```

2. **Activate the virtual environment:**
   - Windows:
     ```powershell
     .venv\Scripts\Activate.ps1
     ```
   - Linux/Mac:
     ```bash
     source .venv/bin/activate
     ```

3. **Copy the local settings template:**
   ```bash
   cp local.settings.json.template local.settings.json
   ```

4. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

5. **Start the Azure Functions runtime:**
   ```bash
   func start
   ```

## Configuration Files

- **host.json**: Azure Functions runtime configuration
- **local.settings.json**: Local development settings (not tracked in git)
- **requirements.txt**: Python dependencies
- **function_app.py**: Main function app with HTTP triggers

## Troubleshooting

### Missing Assembly Error

If you encounter the error:
```
Could not load file or assembly 'Microsoft.Extensions.Configuration.Json, Version=8.0.0.0'
```

This typically indicates one of the following issues:

1. **Azure Functions Core Tools Installation**: The Core Tools may be corrupted or incomplete
   - Solution: Reinstall Azure Functions Core Tools
   ```bash
   npm install -g azure-functions-core-tools@4 --unsafe-perm true
   ```

2. **Extension Bundle Version**: Ensure the extension bundle in `host.json` is compatible
   - The current configuration uses version `[4.*, 5.0.0)`
   - This should be compatible with Functions Runtime 4.x

3. **.NET Runtime**: Azure Functions Core Tools requires .NET runtime
   - Ensure you have .NET 6.0 or later installed
   - Download from: https://dotnet.microsoft.com/download

4. **Clear Function App Cache**:
   ```bash
   # Remove cached files
   rm -rf bin obj .python_packages
   ```

### Python Version

Ensure you're using Python 3.9 or later. Check your version:
```bash
python --version
```

## Project Structure

```
Travel-site/
├── app/                    # Static website files
│   ├── assets/            # Images and icons
│   └── index.html         # Main HTML page
├── function_app.py        # Azure Functions app
├── host.json             # Functions runtime config
├── local.settings.json   # Local settings (gitignored)
├── requirements.txt      # Python dependencies
└── .funcignore          # Files to exclude from deployment
```

## Functions

### HttpTriggerExample

An example HTTP trigger function that demonstrates basic functionality.

**Endpoint:** `/api/hello`
**Method:** GET/POST
**Parameters:**
- `name` (optional): Name for personalized greeting

**Example:**
```bash
curl http://localhost:7071/api/hello?name=World
```

## Development

The static website is located in the `app/` directory. The Azure Functions provide backend APIs for the website.

## Deployment

To deploy to Azure:

1. Create an Azure Function App in the Azure Portal
2. Deploy using Azure Functions Core Tools:
   ```bash
   func azure functionapp publish <FunctionAppName>
   ```

Or use GitHub Actions, Azure DevOps, or other CI/CD tools.
