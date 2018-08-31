nginx:
  ng:
    server:
      config:
      extra_config:
        logging:
          log_format app_metrics: >-
            'time=$time_iso8601
            client=$remote_addr
            method=$request_method
            request="$request"
            request_length=$request_length
            status=$status
            bytes_sent=$bytes_sent
            body_bytes_sent=$body_bytes_sent
            referer=$http_referer
            user_agent="$http_user_agent"
            upstream_addr=$upstream_addr
            upstream_status=$upstream_status
            request_time=$request_time
            request_id=$request_id
            upstream_response_time=$upstream_response_time
            upstream_connect_time=$upstream_connect_time
            upstream_header_time=$upstream_header_time'
          access_log: /var/log/nginx/access.log app_metrics
