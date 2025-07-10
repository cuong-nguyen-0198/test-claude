<?php

namespace App\Services;

use App\Jobs\UserSendMailJob;
use App\Models\User;
use App\Repositories\UserRepository;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class UserService
{
    protected UserRepository $userRepository;
    protected SlackService $slackService;

    public function __construct(
        UserRepository $userRepository,
        SlackService $slackService
    )
    {
        $this->userRepository = $userRepository;
        $this->slackService = $slackService;
    }

    public function getAllUsers(): Collection
    {
        return $this->userRepository->getAll();
    }

    public function getUsersPaginated(int $perPage = 15): LengthAwarePaginator
    {
        return $this->userRepository->paginate($perPage);
    }

    public function getUserById(int $id): ?User
    {
        return $this->userRepository->findById($id);
    }

    public function createUser(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $dataForm = $data;
            $data['password'] = Hash::make($data['password']);
            $userCreated = $this->userRepository->create($data);

            UserSendMailJob::dispatch($userCreated, $dataForm);
            return $userCreated;
        });
    }

    public function updateUser(int $id, array $data): bool
    {
        if (isset($data['password'])) {
            $data['password'] = Hash::make($data['password']);
        }
        return $this->userRepository->update($id, $data);
    }

    public function deleteUser(int $id): bool
    {
        return $this->userRepository->delete($id);
    }

    public function getUserByEmail(string $email): ?User
    {
        return $this->userRepository->findByEmail($email);
    }

    public function userExistsByEmail(string $email): bool
    {
        return $this->getUserByEmail($email) !== null;
    }
}
