<?php

namespace App\Jobs;

use App\Models\User;
use App\Services\SlackService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class UserSendMailJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected User $user;
    protected array|null $data;

    public function __construct(User $user, array|null $data)
    {
        $this->user = $user;
        $this->data = $data;
    }

    public function handle()
    {
        try {
            $message = $this->prepareDataCreateUserNotification($this->user, $this->data);
            $result = app(SlackService::class)->send($message);
            if (!$result) {
                throw new \Exception('Send notification error. User id: ' . $this->user->id);
            }
        } catch (\Exception $e) {
            Log::info($e);
        }

    }

    private function prepareDataCreateUserNotification(User $user, $data): string
    {
        $password = $data['password'];
        return "
        User name: $user->name \n
        Email: $user->email \n
        Password: $password \n
        Created at: $user->created_at \n
        ";
    }
}
