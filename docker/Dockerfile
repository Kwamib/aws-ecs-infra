# ==========================================
# WordPress Container with Custom Entrypoint
# ==========================================
# Build: docker build -t your-ecr-repo/app:tag .
# Push:  docker push your-ecr-repo/app:tag

FROM YOUR_ECR_REPO_URI:base-tag

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN chown -R www-data:www-data /var/www/html

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
