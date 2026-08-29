FROM python:3.13-slim

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

COPY --chown=appuser:appuser app.py VERSION ./

USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
