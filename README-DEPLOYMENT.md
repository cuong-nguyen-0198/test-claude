# Laravel 10 API with AWS ECS Deployment

A Laravel 10 application with CRUD user functionality, clean architecture using service-repository pattern, comprehensive API tests, and automated deployment to AWS ECS.

## Features

- **Clean Architecture**: Service-Repository pattern implementation
- **CRUD API**: Complete REST API for user management
- **Validation**: Request validation with custom form requests
- **Testing**: Comprehensive integration tests
- **Docker**: Multi-stage builds for development and production
- **CI/CD**: GitHub Actions workflow for automated deployment
- **AWS ECS**: Production-ready deployment to AWS

## Project Structure

```
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   └── UserController.php
│   │   └── Requests/
│   │       ├── CreateUserRequest.php
│   │       └── UpdateUserRequest.php
│   ├── Models/
│   │   └── User.php
│   ├── Repositories/
│   │   └── UserRepository.php
│   └── Services/
│       └── UserService.php
├── tests/
│   └── Feature/
│       └── UserApiTest.php
├── .aws/
│   └── task-definition.json
├── .docker/
│   ├── nginx/
│   ├── php/
│   ├── supervisor/
│   └── scripts/
├── .github/
│   └── workflows/
│       └── deploy.yml
└── scripts/
    ├── deploy.sh
    └── setup-aws.sh
```

## API Endpoints

| Method | URI | Description |
|--------|-----|-------------|
| GET | `/api/users` | List users with pagination |
| POST | `/api/users` | Create new user |
| GET | `/api/users/{id}` | Get single user |
| PUT | `/api/users/{id}` | Update user |
| DELETE | `/api/users/{id}` | Delete user |

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Git

### Quick Start

1. **Clone the repository**
```bash
git clone <repository-url>
cd laravel-ecs-app
```

2. **Start development environment**
```bash
docker-compose up -d
```

3. **Install dependencies**
```bash
docker exec laravel_app composer install
```

4. **Run migrations**
```bash
docker exec laravel_app php artisan migrate
```

5. **Run tests**
```bash
docker exec laravel_app php artisan test
```

The application will be available at `http://localhost:8000`

## Production Deployment

### AWS Infrastructure Setup

1. **Configure AWS CLI**
```bash
aws configure
```

2. **Run infrastructure setup script**
```bash
./scripts/setup-aws.sh
```

This will create:
- ECR repository
- VPC with subnets and security groups
- ECS cluster
- IAM roles
- RDS MySQL instance
- ElastiCache Redis cluster
- Application Load Balancer

3. **Update configuration files**
- Update `.aws/task-definition.json` with your AWS account ID
- Update `.env.production` with your RDS and ElastiCache endpoints

### GitHub Actions Deployment

1. **Set up GitHub Secrets**
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
SLACK_WEBHOOK (optional)
```

2. **Push to main branch**
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

The GitHub Actions workflow will automatically:
- Run tests
- Build Docker image
- Push to ECR
- Deploy to ECS

### Manual Deployment

You can also deploy manually using the deployment script:

```bash
./scripts/deploy.sh --migrate --clear-cache
```

## Testing

### Run all tests
```bash
docker exec laravel_app php artisan test
```

### Run specific test file
```bash
docker exec laravel_app php artisan test tests/Feature/UserApiTest.php
```

### Test coverage
```bash
docker exec laravel_app php artisan test --coverage
```

## API Usage Examples

### Create User
```bash
curl -X POST http://localhost:8000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123",
    "password_confirmation": "password123"
  }'
```

### Get Users
```bash
curl http://localhost:8000/api/users?per_page=10
```

### Update User
```bash
curl -X PUT http://localhost:8000/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Updated",
    "email": "john.updated@example.com"
  }'
```

### Delete User
```bash
curl -X DELETE http://localhost:8000/api/users/1
```

## Architecture

### Service-Repository Pattern

The application follows a clean architecture with:

- **Controllers**: Handle HTTP requests and responses
- **Services**: Business logic layer
- **Repositories**: Data access layer
- **Models**: Data models and relationships

### Benefits

- **Separation of Concerns**: Each layer has a specific responsibility
- **Testability**: Easy to unit test business logic
- **Maintainability**: Changes in one layer don't affect others
- **Scalability**: Easy to add new features and functionality

## Security

- Password hashing with bcrypt
- Input validation and sanitization
- CORS protection
- Rate limiting (can be added)
- SQL injection prevention through Eloquent ORM

## Performance

- **Redis Caching**: Session and cache storage
- **Database Optimization**: Proper indexing and query optimization
- **Docker Multi-stage**: Optimized production images
- **OpCache**: PHP bytecode caching enabled
- **Nginx**: High-performance web server

## Monitoring

- **Health Checks**: Application health endpoint
- **Logs**: Centralized logging with CloudWatch
- **Metrics**: ECS and RDS monitoring
- **Alerts**: CloudWatch alarms for critical metrics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License.