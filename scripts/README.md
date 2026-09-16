# scripts

Repo-root orchestration glue only — never business logic (per the repo's services-first architecture rules; business logic belongs inside the `services/<name>/` it concerns). Empty for now. The first scripts expected here, per `implementationPlan/01-repo-bootstrap.md` (E1-T3, E1-T4): a pre-commit hook runner and anything the health-check cron workflow needs beyond a plain HTTP call.
