.DEFAULT_GOAL := help

restart: ## Restart all
	@git pull
	@make -s nginx-restart
	@make -s db-restart
	@make -s app-restart

app-restart: ## Restart Server
	@sudo systemctl daemon-reload
	@bundle 1> /dev/null
	@sudo systemctl restart web-ruby.service
	@echo 'Restart ruby'

app-log: ## Tail server log
	@sudo journalctl -f -u web-ruby.service

nginx-restart: ## Restart nginx
	@sudo cp /dev/null /var/log/nginx/access.log
	@sudo cp nginx.conf /etc/nginx/
	@echo '--- Validate nginx.conf ---'
	@sudo nginx -t
	@echo '--- Validate end ---'
	@sudo systemctl restart nginx
	@echo 'Restart nginx'

nginx-log: ## Tail nginx access.log
	@sudo tail -f /var/log/nginx/access.log

nginx-error-log: ## Tail nginx error.log
	@sudo tail -f /var/log/nginx/error.log

nginx-alp: ## Run alp
	@sudo alp ltsv --file /var/log/nginx/access.log --sort sum --reverse --matching-groups '/api/schedules/[a-zA-Z0-9]+' > alp.txt
	@./dispost -f alp.txt

db-restart: ## Restart mysql
	@sudo cp /dev/null /var/log/mysql/mysql-slow.log
	@sudo cp my.cnf /etc/mysql/
	@sudo systemctl restart mysql
	@echo 'Restart mysql'
	@sudo cp -r sql/ /home/isucon/webapp/
	@/home/isucon/webapp/tools/initdb
	@echo 'Reset schema'

db-digest: ## Analyze mysql-slow.log by pt-query-digest
	@sudo pt-query-digest /var/log/mysql/mysql-slow.log > digest.txt
	@./dispost -f digest.txt

log: ## Tail journalctl
	@sudo journalctl -f

.PHONY: help
help:
	@grep -E '^[a-z0-9A-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
