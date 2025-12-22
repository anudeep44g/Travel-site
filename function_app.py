import azure.functions as func
import logging

app = func.FunctionApp()

@app.function_name(name="HttpTriggerExample")
@app.route(route="hello", auth_level=func.AuthLevel.ANONYMOUS)
def http_trigger(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
            name = req_body.get('name')
        except (ValueError, KeyError):
            logging.debug('Unable to parse request body as JSON or extract name field')
            pass

    if name:
        return func.HttpResponse(f"Hello, {name}! This HTTP triggered function executed successfully.")
    else:
        return func.HttpResponse(
             "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
             status_code=200
        )
