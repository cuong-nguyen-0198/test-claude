<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class SlackService
{
    protected string $webhookUrl;

    public function __construct()
    {
        $this->webhookUrl = config('services.slack.webhook_url');
    }

    public function send(string $message): bool
    {
        $response = Http::post($this->webhookUrl, [
            'text' => $message
        ]);

        return $response->successful();
    }
}
