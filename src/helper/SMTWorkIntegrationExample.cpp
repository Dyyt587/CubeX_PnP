// ============================================================================
// 文件: src/helper/SMTWorkIntegrationExample.cpp
// 说明: SMTWork 串口通信集成示例
// ============================================================================

#include "SMTWork.h"
#include "SerialPortManager.h"
#include <QDebug>

/**
 * 示例1: 简单的运动控制队列
 * 
 * 场景: 执行一系列运动命令，每个命令执行后需要等待设备确认
 */
class MotionControlExample {
public:
    void demonstrateSimpleMotion(SMTWork &work, SerialPortManager &serial) {
        work.setSerialPortManager(&serial);
        
        // 添加一系列运动命令
        work.addWorkItem("MOVE_X 100\n", "ok");
        work.addWorkItem("MOVE_Y 50\n", "ok");
        work.addWorkItem("HOME\n", "homed");
        
        // 监听完成信号
        QObject::connect(&work, &SMTWork::workQueueCompleted, [](){ 
            qDebug() << "所有运动命令执行完成";
        });
        
        // 开始执行
        work.start();
    }
};

/**
 * 示例2: 复杂的生产工序流程
 * 
 * 场景: "拾取-放置-下钉-检查" 的完整工序流程
 */
class ProductionWorkflowExample {
public:
    void demonstrateComplexWorkflow(SMTWork &work, SerialPortManager &serial) {
        work.setSerialPortManager(&serial);
        work.clearWorkQueue();
        
        // 工序1: 移到拾取位置
        work.addWorkItem("MOVE_TO_PICK_POSITION\n", "at_position");
        
        // 工序2: 吸取组件
        work.addWorkItem("VACUUM_ON\n", "ok");
        
        // 工序3: 移到放置位置
        work.addWorkItem("MOVE_TO_PLACE_POSITION\n", "at_position");
        
        // 工序4: 释放真空
        work.addWorkItem("VACUUM_OFF\n", "ok");
        
        // 工序5: 下钉
        work.addWorkItem("PRESS_DOWN 5mm\n", "ok");
        
        // 工序6: 检查放置结果
        work.addWorkItem("CHECK_PLACEMENT\n", "check_ok");
        
        // 连接进度信号
        QObject::connect(&work, &SMTWork::commandSent, 
            [](const QString &cmd) {
                qDebug() << "[执行] " << cmd.trimmed();
            });
        
        QObject::connect(&work, &SMTWork::workItemCompleted, 
            [](int index) {
                const QStringList stages = {
                    "拾取准备", "吸取", "放置准备", "释放", "下钉", "检查"
                };
                if (index < stages.count()) {
                    qDebug() << "[完成] 工序 " << (index+1) << ": " << stages[index];
                }
            });
        
        QObject::connect(&work, &SMTWork::timeoutOccurred, 
            [](const QString &cmd) {
                qDebug() << "[错误] 命令超时: " << cmd.trimmed();
                // 可以在此添加错误恢复逻辑
            });
        
        QObject::connect(&work, &SMTWork::workQueueCompleted, 
            [](){ 
                qDebug() << "[完成] 本次拾取放置工序全部完成";
            });
        
        // 启动工序
        work.start();
    }
};

/**
 * 示例3: 带重试机制的容错流程
 * 
 * 场景: 重要工序需要多次尝试
 */
class RetryWorkflowExample {
public:
    void demonstrateRetryMechanism(SMTWork &work, SerialPortManager &serial) {
        work.setSerialPortManager(&serial);
        work.clearWorkQueue();
        
        // 第一次尝试
        addPickPlaceSequence(work, 1);
        
        // 连接超时信号进行重试
        int retryCount = 0;
        QObject::connect(&work, &SMTWork::timeoutOccurred, 
            [&work, &retryCount](const QString &cmd) {
                retryCount++;
                if (retryCount < 3) {  // 最多重试3次
                    qDebug() << "[重试] 第 " << retryCount << " 次重试";
                    // 可以清空队列后重新启动
                } else {
                    qDebug() << "[失败] 已达最大重试次数";
                }
            });
        
        work.start();
    }

private:
    void addPickPlaceSequence(SMTWork &work, int attempt) {
        QString prefix = QString("[尝试%1] ").arg(attempt);
        work.addWorkItem("MOVE_TO_PICK_POSITION\n", "at_position");
        work.addWorkItem("VACUUM_ON\n", "ok");
        work.addWorkItem("MOVE_TO_PLACE_POSITION\n", "at_position");
        work.addWorkItem("VACUUM_OFF\n", "ok");
    }
};

/**
 * 示例4: 连续生产模式
 * 
 * 场景: 不断产生新的工序队列
 */
class ContinuousProductionExample {
public:
    void demonstrateContinuousProduction(SMTWork &work, SerialPortManager &serial, int numCycles) {
        work.setSerialPortManager(&serial);
        
        int currentCycle = 0;
        auto produceNextCycle = [&]() {
            if (currentCycle < numCycles) {
                currentCycle++;
                qDebug() << "[新周期] 开始第 " << currentCycle << " 个工序周期";
                
                work.clearWorkQueue();
                work.addWorkItem("MOVE_TO_PICK\n", "ok");
                work.addWorkItem("VACUUM_ON\n", "ok");
                work.addWorkItem("MOVE_TO_PLACE\n", "ok");
                work.addWorkItem("VACUUM_OFF\n", "ok");
                
                work.start();
            }
        };
        
        // 连接队列完成信号，自动启动下一个周期
        QObject::connect(&work, &SMTWork::workQueueCompleted, 
            [&produceNextCycle]() { 
                produceNextCycle();
            });
        
        // 启动第一个周期
        produceNextCycle();
    }
};

/**
 * 使用方式汇总
 */

// C++ 中的使用:
// 
// int main() {
//     SMTWork work;
//     SerialPortManager serialPortManager;
//     
//     // 简单示例
//     MotionControlExample motionEx;
//     motionEx.demonstrateSimpleMotion(work, serialPortManager);
//     
//     // 或使用复杂工序
//     ProductionWorkflowExample workflowEx;
//     workflowEx.demonstrateComplexWorkflow(work, serialPortManager);
//     
//     return app.exec();
// }

// QML 中的调用:
// 
// Button {
//     text: "开始拾取放置"
//     onClicked: {
//         smtWork.clearWorkQueue()
//         smtWork.addWorkItem("MOVE_TO_PICK\n", "ok")
//         smtWork.addWorkItem("VACUUM_ON\n", "ok")
//         smtWork.addWorkItem("MOVE_TO_PLACE\n", "ok")
//         smtWork.addWorkItem("VACUUM_OFF\n", "ok")
//         smtWork.start()
//     }
// }
//
// Connections {
//     target: smtWork
//     function onWorkQueueCompleted() {
//         console.log("工序完成，准备下一个")
//     }
//     function onTimeoutOccurred(cmd) {
//         console.log("超时，可能需要检查设备: " + cmd)
//     }
// }
