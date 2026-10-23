## 本节要点

Spring Boot 的核心是**自动装配**：通过 `@SpringBootApplication` 触发扫描，读取 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`（或旧版 `spring.factories`）里的配置类，按条件装配 Bean。理解这条链路，就理解了 Spring Boot 90% 的行为。

## 核心概念

- **@SpringBootApplication**：组合注解 = `@SpringBootConfiguration`（@Configuration）+ `@EnableAutoConfiguration` + `@ComponentScan`。
- **自动装配的三个步骤**：① 读取候选配置类 → ② 按 `@Conditional` 系列注解过滤 → ③ 注册为 Bean 定义。
- **条件注解**：`@ConditionalOnClass`（类路径有才装配）、`@ConditionalOnMissingBean`（用户没定义才装配）、`@ConditionalOnProperty`、`@ConditionalOnBean`。
- **@ConditionalOnMissingBean 的顺序敏感**：用户自定义的 Bean 必须先注册，所以自定义配置要放在自动配置之前。
- **starter 的作用**：一组依赖 + 一份自动配置类。
- **IoC 容器**：BeanFactory → ApplicationContext（Bean 生命周期、事件、国际化等）。
- **Bean 生命周期**：实例化 → 属性填充 → Aware 回调 → BeanPostProcessor 前置 → @PostConstruct → 初始化 → 后置 → @PreDestroy → 销毁。
- **BeanPostProcessor**：最关键的扩展点，AOP、@Autowired 的注入都靠它。
- **Bean 的作用域**：singleton（默认）、prototype、request、session。
- **循环依赖**：Spring 用三级缓存解决单例的字段注入循环依赖（构造器注入无法解决）。
- **配置方式**：application.yml > @ConfigurationProperties > @Value。
- **Actuator**：健康检查、指标、环境信息。

## 关键代码

```java
@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

// 自定义配置：属性绑定
@ConfigurationProperties(prefix = "app.learning")
public record LearningProperties(int maxTasks, Duration timeout, boolean enabled) {
    // 构造器绑定（推荐）：record + @ConfigurationProperties
}

// 使用
@Service
public class TaskService {
    private final LearningProperties props;
    public TaskService(LearningProperties props) { this.props = props; }
}

// 条件装配示例
@Configuration
@ConditionalOnClass(RedisTemplate.class)
@ConditionalOnMissingBean(name = "customRedis")
public class RedisAutoConfig {
    @Bean
    public RedisTemplate<String, Object> redisTemplate() { ... }
}
```

> 注意：代码需 JDK 17 及以上，直接复制即可编译运行。

## 常见误区

- 认为 `@SpringBootApplication` 只能放在启动类——它会扫描所在包及子包
- 以为 `@ComponentScan` 会扫到所有依赖 jar——默认只扫启动类所在包
- 把 Bean 定义写在自动配置类里却不加 `@ConditionalOnMissingBean`，导致用户无法覆盖
- 用 `@Value` 注入复杂配置——类型受限且不支持嵌套结构，应该用 `@ConfigurationProperties`
- 构造器注入与字段注入混用

## 动手练习

写一个自定义 starter：包含 `XxxProperties`（`@ConfigurationProperties`）与 `XxxAutoConfiguration`（`@ConditionalOnMissingBean`），并在另一个项目中通过依赖引入。

## 延伸阅读（来自「Java江湖」知识库）

知识库中的《SpringIOC核心技术-冰河》《Spring源码深度解析（第 2 版）》《Spring 源码解析手册（星球专享）》《面渣逆袭 Spring 篇》《面试题-17-Spring Boot面试题》对本节原理有系统覆盖。

**自动装配的完整机制**

《SpringIOC核心技术-冰河》对 Spring 的 IOC 实现原理拆解得很细，与 Boot 的自动装配一脉相承：

```
启动 → SpringApplication.run()
  → 创建 ApplicationContext
  → 加载配置类（@SpringBootApplication 触发 @ComponentScan）
  → 读取 AutoConfiguration.imports 中的候选配置类
  → @Conditional 过滤（OnClass / OnMissingBean / OnProperty ...）
  → 注册 BeanDefinition
  → refresh() → 实例化单例 → 属性注入 → AOP 代理
```

《Spring源码深度解析（第 2 版）》与《Spring 源码解析手册》补充了 Spring Boot 2.7 之后的关键变化：**自动配置类注册文件的路径从 `META-INF/spring.factories` 改到了 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`**。原因是对 `spring.factories` 的自动配置支持被废弃，且一个文件只能声明一个自动配置类，新格式支持一行声明多个。

**条件注解体系**

《面试题-17-Spring Boot面试题》与《面渣逆袭 Spring 篇》列出了常用条件注解：

| 注解 | 生效条件 |
| --- | --- |
| `@ConditionalOnClass` | 类路径中存在指定类 |
| `@ConditionalOnMissingClass` | 类路径中**不**存在指定类 |
| `@ConditionalOnBean` | 容器中已有指定类型的 Bean |
| `@ConditionalOnMissingBean` | 容器中**没有**指定类型的 Bean |
| `@ConditionalOnProperty` | 配置项匹配指定值 |
| `@ConditionalOnWebApplication` | 是 Web 应用 |
| `@ConditionalOnExpression` | SpEL 表达式为真 |

**@ConditionalOnMissingBean 的使用规范**

《SpringIOC核心技术-冰河》与《面试题-17》强调这是 starter 开发的核心：

```java
@Bean
@ConditionalOnMissingBean      // 用户自己定义了就用用户的
public XxxService xxxService() { return new XxxService(); }
```

**顺序问题**：Spring Boot 2.0 之前要求自定义配置类放在 `@SpringBootApplication` 之后（因为自动配置在后处理）。2.1 之后改用 `AutoConfigureBefore` / `AutoConfigureAfter` 显式控制：

```java
@Configuration
@AutoConfigureBefore(MyAutoConfig.class)
public class MyConfig { ... }
```

**Bean 的生命周期与 BeanPostProcessor**

《SpringIOC核心技术-冰河》给出了完整生命周期：

```
实例化（构造器）
  → 属性填充（@Autowired、@Value）
  → Aware 接口回调（BeanNameAware / BeanFactoryAware / ApplicationContextAware）
  → BeanPostProcessor#postProcessBeforeInitialization（@PostConstruct 在此之后）
  → InitializingBean#afterPropertiesSet
  → BeanPostProcessor#postProcessAfterInitialization（AOP 代理在此生成）
  → 使用
  → @PreDestroy → DisposableBean#destroy → 自定义 destroy 方法
```

书中强调 **BeanPostProcessor 是 Spring 扩展的命脉**——AOP 代理、`@Autowired` 的注入、`@Async` 的异步化，全都在这里织入。

**循环依赖的三级缓存**

《Spring源码深度解析（第 2 版）》与《深入浅出Java+23种设计模式》都解释了三级缓存：

```
一级：singletonObjects      —— 完全初始化好的单例
二级：earlySingletonObjects —— 提前暴露的单例（可能还在填充属性）
三级：singletonFactories    —— 工厂函数（用于生成早期引用）
```

三级缓存是为了处理「A 的构造需要 B，B 的构造需要 A」这种**构造器注入**的循环依赖——三级缓存能拿到**原始引用**（可能是代理对象前的裸对象）。

**但字段注入的循环依赖是有害的**，《面试题-17》明确指出应当避免：

```java
// 不推荐：字段注入循环依赖
@Service class A { @Autowired B b; }
@Service class B { @Autowired A a; }

// 推荐：构造器注入（会在启动时快速失败）
@Service class A { A(B b) { this.b = b; } }
```

**@Value vs @ConfigurationProperties**

《面渣逆袭 Spring 篇》给出明确对比：

| | `@Value` | `@ConfigurationProperties` |
| --- | --- | --- |
| 粒度 | 单个属性 | 一批属性（一个类） |
| 类型 | 只支持简单类型 | 支持任意类型（嵌套对象、List、Map、Duration） |
| 校验 | 不支持 | 支持 JSR-303（`@Validated`） |
| 元数据 | 无 | 可生成 IDE 提示（配置元数据） |
| 写法 | `@Value("${a.b}")` | `@ConfigurationProperties(prefix="a.b")` |

**推荐做法**（书中给出）：

```java
@ConfigurationProperties(prefix = "app")
@Validated
public record AppProperties(
        @Min(1) @Max(100) int maxPoolSize,
        Duration timeout,
        Map<String, String> extras) {
}
```

**AOP 与动态代理**

《面渣逆袭 Spring 篇》指出 Spring AOP 的两种实现：JDK 动态代理（需接口）与 CGLIB（字节码增强）。Spring Boot 2.x 起默认 CGLIB。

《Spring 源码解析手册》补充了一个易踩的坑：**CGLIB 代理下 `@Transactional` 自调用失效**——因为代理对象与目标对象是不同实例，内部 `this.method()` 调用不经过代理。

```java
@Service
public class OrderService {
    public void outer() {
        this.inner();      // 自调用，不走代理 → @Transactional 不生效
    }
    @Transactional
    public void inner() { ... }
}
```

**常见 Starter 依赖坐标**

《面试题-17-Spring Boot面试题》提到官方 starter 的命名规范：

```
spring-boot-starter-web
spring-boot-starter-data-jpa
spring-boot-starter-test
mybatis-spring-boot-starter
```

自定义 starter 的命名一般是 `xxx-spring-boot-starter`。

**配置文件优先级**

《面渣逆袭 Spring 篇》给出 Spring Boot 配置的优先级顺序（高到低）：

1. 命令行参数 `--server.port=8081`
2. `SPRING_APPLICATION_JSON` 环境变量
3. ServletConfig / ServletContext 参数
4. JNDI（java:comp/env）
5. Java System Properties（`System.getProperties()`）
6. OS 环境变量
7. 打包外的 application.yml/properties
8. 打包内的 application.yml/properties
9. `@Profile` 指定的配置文件
10. `@PropertySource`

**Actuator 端点**

《面试题-17》列出了常用的 Actuator 端点：

```
/actuator/health        健康检查
/actuator/info          应用信息
/actuator/env           环境变量（敏感，需鉴权）
/actuator/metrics       指标
/actuator/threaddump    线程栈
/actuator/heapdump      堆快照
```

## 实战提示

**排查启动问题的顺序**：

```bash
# 1. 看自动装配报告（最有用）
java -jar app.jar --debug

# 2. 看某个自动配置为什么没生效
java -jar app.jar --debug=true   # 输出 ConditionEvaluationReport

# 3. 确认 Bean 是否注册
curl http://localhost:8080/actuator/conditions
```

**条件装配报告**是排查「为什么我的 Bean 没被创建」的最快手段——它会列出每个候选配置类**评估了哪些条件、哪个失败了**。

**推荐的配置组织方式**：

```yaml
app:
  learning:
    max-tasks: 10
    timeout: 30s          # Duration 类型：支持 30s / 30m
    features:
      - a
      - b
```

```java
@ConfigurationProperties(prefix = "app.learning")
public record LearningProperties(
        int maxTasks,
        Duration timeout,
        List<String> features) {
}
```

**Bean 注入统一用构造器**：

```java
// 更好：构造器注入 + final 字段
@Service
public class TaskService {
    private final TaskRepository repo;
    private final AppProperties props;

    public TaskService(TaskRepository repo, AppProperties props) {
        this.repo = repo;
        this.props = props;
    }
}
```

理由：① 依赖显式、② 字段可为 final、③ 单元测试可直接 new、④ 循环依赖能在启动时快速暴露。
